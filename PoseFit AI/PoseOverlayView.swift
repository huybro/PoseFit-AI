import SwiftUI
import Vision

struct PoseOverlayView: View {
    let poses: [VNHumanBodyPose3DObservation]
    let frameSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            for pose in poses {
                drawPose(pose: pose, context: context, size: size)
            }
        }
        .allowsHitTesting(false) // Let touches pass through
    }
    
    private func drawPose(pose: VNHumanBodyPose3DObservation, context: GraphicsContext, size: CGSize) {
        // First, collect all joint positions from 3D pose
        var jointPositions: [VNHumanBodyPose3DObservation.JointName: CGPoint] = [:]
        
        let jointNames: [VNHumanBodyPose3DObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        // Collect valid joint positions from 3D poses
        for jointName in jointNames {
            if pose.availableJointNames.contains(jointName),
               let point3D = try? pose.recognizedPoint(jointName) {
                // Use Apple's recommended method to project 3D to 2D
                if let imagePoint = try? pose.pointInImage(jointName) {
                    // Convert from normalized coordinates to view coordinates
                    let position = CGPoint(
                        x: imagePoint.x * size.width,
                        y: (1.0 - imagePoint.y) * size.height  // Flip Y for iOS
                    )
                    jointPositions[jointName] = position
                } else {
                    // Fallback: manual projection (if pointInImage fails)
                    let position = CGPoint(
                        x: CGFloat(0.5 + point3D.position.columns.3.x * 0.5) * size.width,
                        y: CGFloat(0.5 - point3D.position.columns.3.y * 0.5) * size.height
                    )
                    jointPositions[jointName] = position
                }
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
    
    private func drawSkeleton(jointPositions: [VNHumanBodyPose3DObservation.JointName: CGPoint], context: GraphicsContext) {
        // Define skeleton connections
        let connections: [(VNHumanBodyPose3DObservation.JointName, VNHumanBodyPose3DObservation.JointName)] = [
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
