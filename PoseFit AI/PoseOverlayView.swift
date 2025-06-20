import SwiftUI
import Vision

struct PoseOverlayView: View {
    let poses: [VNHumanBodyPoseObservation]
    let frameSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            for pose in poses {
                drawPose(pose: pose, context: context, size: size)
            }
        }
        .allowsHitTesting(false) // Let touches pass through
    }
    
    private func drawPose(pose: VNHumanBodyPoseObservation, context: GraphicsContext, size: CGSize) {
        // First, collect all joint positions
        var jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        // Collect valid joint positions
        for jointName in jointNames {
            if let point = try? pose.recognizedPoint(jointName), point.confidence > 0.3 {
                let position = CGPoint(
                    x: (1 - point.location.y) * size.width,
                    y: point.location.x * size.height
                )
                jointPositions[jointName] = position
            }
        }
        
        // Draw skeleton lines FIRST (so they appear behind dots)
        drawSkeleton(jointPositions: jointPositions, context: context)
        
        // Then draw joints as circles on top
        for position in jointPositions.values {
            context.fill(
                Path(ellipseIn: CGRect(x: position.x - 5, y: position.y - 5, width: 10, height: 10)),
                with: .color(.green)
            )
        }
    }
    
    private func drawSkeleton(jointPositions: [VNHumanBodyPoseObservation.JointName: CGPoint], context: GraphicsContext) {
        // Define skeleton connections
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            // Arms
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            
            // Torso
            (.leftShoulder, .rightShoulder),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .rightHip),
            
            // Legs
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
            
        ]
        
        // Draw each connection
        for (startJoint, endJoint) in connections {
            if let startPos = jointPositions[startJoint],
               let endPos = jointPositions[endJoint] {
                
                var path = Path()
                path.move(to: startPos)
                path.addLine(to: endPos)
                
                context.stroke(path, with: .color(.blue), lineWidth: 3)
            }
        }
    }
}
