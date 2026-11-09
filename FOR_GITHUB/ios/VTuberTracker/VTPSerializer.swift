import Foundation
import ARKit

public struct VTPConstants {
    public static let magic: UInt32 = 0x50555456 // 'VTUP' Little-Endian
    public static let version: UInt8 = 0x01
    public static let packetSize: Int = 302
}

public struct VTPJointData {
    public var x: UInt16 = 0
    public var y: UInt16 = 0
    public var confidence: UInt8 = 0
    public init(x: UInt16 = 0, y: UInt16 = 0, confidence: UInt8 = 0) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public final class VTPSerializer {
    public static let shared = VTPSerializer()
    
    // Exact canonical order of 52 ARKit blendshapes
    public let blendShapeKeys: [ARFaceAnchor.BlendShapeLocation] = [
        .browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight, .eyeBlinkLeft, .eyeBlinkRight,
        .eyeLookDownLeft, .eyeLookDownRight, .eyeLookInLeft, .eyeLookInRight,
        .eyeLookOutLeft, .eyeLookOutRight, .eyeLookUpLeft, .eyeLookUpRight,
        .eyeSquintLeft, .eyeSquintRight, .eyeWideLeft, .eyeWideRight,
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight, .mouthFrownLeft, .mouthFrownRight,
        .mouthFunnel, .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker, .mouthRight,
        .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper,
        .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight, .noseSneerLeft, .noseSneerRight,
        .tongueOut
    ]
    
    public func serialize(
        faceAnchor: ARFaceAnchor?,
        sequenceNumber: UInt16,
        timestamp: UInt64,
        leftHandJoints: [VTPJointData],
        rightHandJoints: [VTPJointData],
        hasLeftHand: Bool,
        hasRightHand: Bool
    ) -> Data {
        var buffer = [UInt8]()
        buffer.reserveCapacity(VTPConstants.packetSize)
        
        // 1. Magic: 4 bytes
        var magic = VTPConstants.magic.littleEndian
        withUnsafeBytes(of: &magic) { buffer.append(contentsOf: $0) }
        
        // 2. Version: 1 byte
        buffer.append(VTPConstants.version)
        
        // 3. Flags: 1 byte
        var flags: UInt8 = 0
        if let face = faceAnchor, face.isTracked { flags |= (1 << 0) }
        if hasLeftHand { flags |= (1 << 1) }
        if hasRightHand { flags |= (1 << 2) }
        buffer.append(flags)
        
        // 4. Sequence Number: 2 bytes
        var seq = sequenceNumber.littleEndian
        withUnsafeBytes(of: &seq) { buffer.append(contentsOf: $0) }
        
        // 5. Timestamp: 8 bytes
        var time = timestamp.littleEndian
        withUnsafeBytes(of: &time) { buffer.append(contentsOf: $0) }
        
        // 6. Head Pose: 24 bytes (Position 3x Float32, Euler Angles 3x Float32)
        if let transform = faceAnchor?.transform {
            var px = Float(transform.columns.3.x).bitPattern.littleEndian
            var py = Float(transform.columns.3.y).bitPattern.littleEndian
            var pz = Float(transform.columns.3.z).bitPattern.littleEndian
            withUnsafeBytes(of: &px) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &py) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &pz) { buffer.append(contentsOf: $0) }
            
            let pitch = Float(asin(min(max(-transform.columns.2.y, -1.0), 1.0)))
            let yaw   = Float(atan2(transform.columns.2.x, transform.columns.2.z))
            let roll  = Float(atan2(transform.columns.0.y, transform.columns.1.y))
            
            var rRoll  = roll.bitPattern.littleEndian
            var rPitch = pitch.bitPattern.littleEndian
            var rYaw   = yaw.bitPattern.littleEndian
            withUnsafeBytes(of: &rRoll)  { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &rPitch) { buffer.append(contentsOf: $0) }
            withUnsafeBytes(of: &rYaw)   { buffer.append(contentsOf: $0) }
        } else {
            buffer.append(contentsOf: [UInt8](repeating: 0, count: 24))
        }
        
        // 7. 52 Blendshapes: 52 bytes
        let blendShapesDict = faceAnchor?.blendShapes ?? [:]
        for key in blendShapeKeys {
            let val = blendShapesDict[key]?.floatValue ?? 0.0
            let quantized = UInt8(clamping: Int(max(0.0, min(1.0, val)) * 255.0 + 0.5))
            buffer.append(quantized)
        }
        
        // 8. Hands: 21 joints x 5 bytes x 2 hands = 210 bytes
        let appendHand = { (joints: [VTPJointData]) in
            for i in 0..<21 {
                let j = (i < joints.count) ? joints[i] : VTPJointData()
                var x = j.x.littleEndian
                var y = j.y.littleEndian
                withUnsafeBytes(of: &x) { buffer.append(contentsOf: $0) }
                withUnsafeBytes(of: &y) { buffer.append(contentsOf: $0) }
                buffer.append(j.confidence)
            }
        }
        appendHand(leftHandJoints)
        appendHand(rightHandJoints)
        
        return Data(buffer)
    }
}
