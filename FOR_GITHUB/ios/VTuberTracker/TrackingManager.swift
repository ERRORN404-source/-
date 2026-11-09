import Foundation
import ARKit
import Vision
import Network
import SwiftUI
import Combine
import UIKit
import os

public enum TransportMode {
    case udp
    case usbTcp
}

public final class TrackingManager: NSObject, ObservableObject, ARSessionDelegate {
    public static let shared = TrackingManager()
    
    public let session = ARSession()
    private var connection: NWConnection?
    private let networkQueue = DispatchQueue(label: "com.vtuber.netQueue", qos: .userInteractive)
    private let visionQueue = DispatchQueue(label: "com.vtuber.visionQueue", qos: .userInitiated)
    
    // Status & Telemetry
    @Published public var isStreaming: Bool = false
    @Published public var fps: Int = 0
    @Published public var packetsSent: UInt64 = 0
    @Published public var currentHost: String = ""
    @Published public var mode: TransportMode = .udp
    
    // Configurable Settings
    @Published public var enableHandTracking: Bool = true
    @Published public var eyeSensitivity: Float = 1.0
    @Published public var mouthSensitivity: Float = 1.0
    
    // Live Blendshape Telemetry for UI HUD
    @Published public var liveJawOpen: Float = 0
    @Published public var liveEyeBlinkLeft: Float = 0
    @Published public var liveEyeBlinkRight: Float = 0
    @Published public var liveMouthSmile: Float = 0
    @Published public var liveHasLeftHand: Bool = false
    @Published public var liveHasRightHand: Bool = false
    
    private var sequenceNumber: UInt16 = 0
    private var isVisionBusy = false
    private var fpsCounter = 0
    private var lastFpsDate = Date()
    private var uiUpdateCounter = 0
    
    private var leftHandJoints = Array(repeating: VTPJointData(), count: 21)
    private var rightHandJoints = Array(repeating: VTPJointData(), count: 21)
    private var hasLeftHand = false
    private var hasRightHand = false
    private let handLock = os_unfair_lock_t.allocate(capacity: 1)
    
    public override init() {
        super.init()
        handLock.initialize(to: os_unfair_lock())
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.fps = self.fpsCounter
            self.fpsCounter = 0
        }
    }
    
    public func start(host: String, port: UInt16, mode: TransportMode = .udp) {
        self.currentHost = host
        self.mode = mode
        
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let params: NWParameters
        
        if mode == .udp {
            params = NWParameters.udp
        } else {
            params = NWParameters.tcp
        }
        
        connection = NWConnection(host: endpoint, port: nwPort, using: params)
        connection?.stateUpdateHandler = { state in
            print("[Tracker Network] State: \(state)")
        }
        connection?.start(queue: networkQueue)
        
        guard ARFaceTrackingConfiguration.isSupported else {
            print("[Error] ARFaceTracking is not supported on this device")
            return
        }
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        config.providesAudioData = false
        config.worldAlignment = .camera
        
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        UIApplication.shared.isIdleTimerDisabled = true
        self.isStreaming = true
        self.packetsSent = 0
    }
    
    public func stop() {
        session.pause()
        connection?.cancel()
        connection = nil
        isStreaming = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - ARSessionDelegate 60 FPS
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first as? ARFaceAnchor else { return }
        fpsCounter += 1
        packetsSent &+= 1
        
        let timestamp = UInt64(session.currentFrame?.timestamp ?? ProcessInfo.processInfo.systemUptime * 1_000_000)
        
        // Update Live UI Telemetry at ~15 FPS
        uiUpdateCounter += 1
        if uiUpdateCounter % 4 == 0 {
            let jaw = faceAnchor.blendShapes[.jawOpen]?.floatValue ?? 0
            let blinkL = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
            let blinkR = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
            let smileL = faceAnchor.blendShapes[.mouthSmileLeft]?.floatValue ?? 0
            let smileR = faceAnchor.blendShapes[.mouthSmileRight]?.floatValue ?? 0
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.liveJawOpen = jaw
                self.liveEyeBlinkLeft = blinkL
                self.liveEyeBlinkRight = blinkR
                self.liveMouthSmile = (smileL + smileR) * 0.5
                self.liveHasLeftHand = self.hasLeftHand
                self.liveHasRightHand = self.hasRightHand
            }
        }
        
        // Dispatch Apple Vision hand detection on Neural Engine if enabled
        if enableHandTracking, let pixelBuffer = session.currentFrame?.capturedImage, !isVisionBusy {
            isVisionBusy = true
            visionQueue.async { [weak self] in
                self?.processHandPose(pixelBuffer: pixelBuffer)
                self?.isVisionBusy = false
            }
        }
        
        os_unfair_lock_lock(handLock)
        let lHand = leftHandJoints
        let rHand = rightHandJoints
        let hasL = enableHandTracking ? hasLeftHand : false
        let hasR = enableHandTracking ? hasRightHand : false
        os_unfair_lock_unlock(handLock)
        
        let packetData = VTPSerializer.shared.serialize(
            faceAnchor: faceAnchor,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            leftHandJoints: lHand,
            rightHandJoints: rHand,
            hasLeftHand: hasL,
            hasRightHand: hasR
        )
        
        sequenceNumber = sequenceNumber &+ 1
        
        connection?.send(content: packetData, completion: .idempotent)
    }
    
    // MARK: - Vision Hand Pose Detection
    private func processHandPose(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
        
        guard let observations = request.results else { return }
        
        var tempLeft = Array(repeating: VTPJointData(), count: 21)
        var tempRight = Array(repeating: VTPJointData(), count: 21)
        var foundLeft = false
        var foundRight = false
        
        let jointKeys: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        
        for observation in observations {
            let isRight = (observation.chirality == .right)
            var extracted = Array(repeating: VTPJointData(), count: 21)
            
            for (idx, jointKey) in jointKeys.enumerated() {
                if let pt = try? observation.recognizedPoint(jointKey), pt.confidence > 0.15 {
                    extracted[idx] = VTPJointData(
                        x: UInt16(clamping: Int(pt.location.x * 65535.0)),
                        y: UInt16(clamping: Int((1.0 - pt.location.y) * 65535.0)),
                        confidence: UInt8(clamping: Int(pt.confidence * 255.0))
                    )
                }
            }
            
            if isRight {
                tempRight = extracted
                foundRight = true
            } else {
                tempLeft = extracted
                foundLeft = true
            }
        }
        
        os_unfair_lock_lock(handLock)
        self.leftHandJoints = tempLeft
        self.rightHandJoints = tempRight
        self.hasLeftHand = foundLeft
        self.hasRightHand = foundRight
        os_unfair_lock_unlock(handLock)
    }
}
