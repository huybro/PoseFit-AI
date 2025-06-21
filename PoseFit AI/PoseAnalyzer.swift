import Foundation
import Vision

class PoseAnalyzer {
    
    // Analyze squat form
    static func analyzeSquat(pose: VNHumanBodyPoseObservation) -> WorkoutAnalysis? {
        // Get all required joints with proper coordinate conversion
        guard let leftKnee = try? pose.recognizedPoint(.leftKnee),
              let rightKnee = try? pose.recognizedPoint(.rightKnee),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              let leftAnkle = try? pose.recognizedPoint(.leftAnkle),
              let rightAnkle = try? pose.recognizedPoint(.rightAnkle),
              let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              // Check confidence
              leftKnee.confidence > 0.5, rightKnee.confidence > 0.5,
              leftHip.confidence > 0.5, rightHip.confidence > 0.5,
              leftAnkle.confidence > 0.5, rightAnkle.confidence > 0.5 else {
            return nil
        }
        
        // Convert to normalized coordinates (flip Y for iOS)
        let leftKneePoint = normalizePoint(leftKnee.location)
        let rightKneePoint = normalizePoint(rightKnee.location)
        let leftHipPoint = normalizePoint(leftHip.location)
        let rightHipPoint = normalizePoint(rightHip.location)
        let leftAnklePoint = normalizePoint(leftAnkle.location)
        let rightAnklePoint = normalizePoint(rightAnkle.location)
        let leftShoulderPoint = normalizePoint(leftShoulder.location)
        let rightShoulderPoint = normalizePoint(rightShoulder.location)
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // 1. KNEE DEPTH ANALYSIS with DEBUG PRINTS
        let leftKneeAngle = calculateAngle(
            pointA: leftHipPoint,
            pointB: leftKneePoint, 
            pointC: leftAnklePoint
        )
        let rightKneeAngle = calculateAngle(
            pointA: rightHipPoint,
            pointB: rightKneePoint,
            pointC: rightAnklePoint
        )
        
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        

        
        metrics["avg_knee_angle"] = avgKneeAngle
        metrics["left_knee_angle"] = leftKneeAngle
        metrics["right_knee_angle"] = rightKneeAngle
        
        // Define ranges instead of strict values
        switch avgKneeAngle {
        case 85...95:
            feedback.append("🏆 Perfect squat depth!")
            
        case 80...84, 96...105:
            feedback.append("✅ Great squat depth!")
            score -= 0.05
            
        case 70...79, 106...115:
            feedback.append(" Good depth - could be slightly better")
            score -= 0.15
            
        case 115...130:
            feedback.append("🔽 Go a bit deeper for better form")
            score -= 0.25
            
        case 50...69:
            feedback.append("⬆️ Too deep - come up slightly")
            score -= 0.20
            
        default:
            if avgKneeAngle > 130 {
                feedback.append("🔽 Much deeper needed - bend those knees!")
                score -= 0.40
            } else {
                feedback.append("⬆️ Way too deep - ease up!")
                score -= 0.35
            }
        }
        
        // 2. KNEE SYMMETRY - more forgiving range
        let kneeAngleDiff = abs(leftKneeAngle - rightKneeAngle)
        metrics["knee_symmetry"] = kneeAngleDiff
        
        switch kneeAngleDiff {
        case 0...5:
            // Perfect symmetry - no feedback needed
            break
        case 6...10:
            feedback.append("⚖️ Nearly balanced - good work!")
            score -= 0.05
        case 11...20:
            feedback.append("⚖️ Try to keep both legs more even")
            score -= 0.15
        default: // > 20
            feedback.append("⚖️ Focus on balancing weight between legs")
            score -= 0.25
        }
        
        // 3. TORSO POSTURE - realistic ranges
        let torsoAngle = calculateTorsoAngle(
            leftShoulder: leftShoulderPoint,
            rightShoulder: rightShoulderPoint,
            leftHip: leftHipPoint,
            rightHip: rightHipPoint
        )
        metrics["torso_angle"] = torsoAngle
        

        
        switch torsoAngle {
        case 15...35:
            feedback.append("📐 Excellent posture!")
            // No penalty
            
        case 10...14, 36...40:
            feedback.append("📐 Good posture - minor adjustment needed")
            score -= 0.05
            
        case 5...9, 41...50:
            if torsoAngle < 15 {
                feedback.append("📐 Lean forward slightly more")
            } else {
                feedback.append("📐 Keep chest up a bit more")
            }
            score -= 0.15
            
        default:
            if torsoAngle > 50 {
                feedback.append("📐 Keep chest up - don't lean too far forward")
                score -= 0.30
            } else {
                feedback.append("📐 Lean forward slightly - engage your core")
                score -= 0.20
            }
        }
        
        // 4. KNEE TRACKING (knees over toes)
        let leftKneeTracking = leftKneePoint.x - leftAnklePoint.x
        let rightKneeTracking = rightKneePoint.x - rightAnklePoint.x
        
        if abs(leftKneeTracking) > 0.1 || abs(rightKneeTracking) > 0.1 {
            feedback.append("🦵 Keep knees aligned over your toes")
            score -= 0.2
        }
        
        // 5. OVERALL SCORE RANGES - more encouraging
        if score >= 0.95 {
            feedback.insert("🏆 Outstanding squat form!", at: 0)
        } else if score >= 0.85 {
            feedback.insert("💪 Excellent squat!", at: 0)
        } else if score >= 0.70 {
            feedback.insert("👍 Good squat - keep it up!", at: 0)
        } else if score >= 0.50 {
            feedback.insert("⚠️ Form improvements needed", at: 0)
        } else {
            feedback.insert("🚨 Focus on basic form", at: 0)
        }
        

        
        return WorkoutAnalysis(
            exercise: .squat,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    // Calculate torso lean angle
    private static func calculateTorsoAngle(leftShoulder: CGPoint, rightShoulder: CGPoint, 
                                          leftHip: CGPoint, rightHip: CGPoint) -> Double {
        let shoulderMidpoint = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipMidpoint = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        let verticalVector = CGPoint(x: 0, y: 1)
        let torsoVector = CGPoint(
            x: shoulderMidpoint.x - hipMidpoint.x,
            y: shoulderMidpoint.y - hipMidpoint.y
        )
        
        let dotProduct = torsoVector.y
        let magnitude = sqrt(torsoVector.x * torsoVector.x + torsoVector.y * torsoVector.y)
        let cosAngle = dotProduct / magnitude
        
        return _math.acos(max(-1, min(1, cosAngle))) * 180.0 / Double.pi
    }
    
    // Calculate angle between three points
    private static func calculateAngle(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Double {
        let vectorBA = CGPoint(x: pointA.x - pointB.x, y: pointA.y - pointB.y)
        let vectorBC = CGPoint(x: pointC.x - pointB.x, y: pointC.y - pointB.y)
        
        let dotProduct = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
        let magnitudeBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
        let magnitudeBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)
        
        let cosAngle = dotProduct / (magnitudeBA * magnitudeBC)
        let angleRadians = acos(max(-1, min(1, cosAngle)))
        return angleRadians * 180.0 / Double.pi
    }
    
    // Add this helper method
    private static func normalizePoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x,           // X stays the same (0-1)
            y: 1.0 - point.y      // Flip Y for iOS coordinate system
        )
    }
    
    // New 3D analysis method
    static func analyzeSquat3D(pose: VNHumanBodyPose3DObservation) -> WorkoutAnalysis? {
        
        // Get 3D joint points - Note: VNHumanBodyRecognizedPoint3D doesn't have confidence property
        guard let leftKnee = try? pose.recognizedPoint(.leftKnee),
              let rightKnee = try? pose.recognizedPoint(.rightKnee),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              let leftAnkle = try? pose.recognizedPoint(.leftAnkle),
              let rightAnkle = try? pose.recognizedPoint(.rightAnkle) else {
            print("❌ 3D: Not enough joints detected for squat analysis")
            return nil
        }
        
        // For 3D poses, we can check if the joint names are available
        guard pose.availableJointNames.contains(.leftKnee),
              pose.availableJointNames.contains(.rightKnee),
              pose.availableJointNames.contains(.leftHip),
              pose.availableJointNames.contains(.rightHip),
              pose.availableJointNames.contains(.leftAnkle),
              pose.availableJointNames.contains(.rightAnkle) else {
            print("❌ 3D: Required joints not available in this pose")
            return nil
        }
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // Calculate 3D knee angles
        let leftKneeAngle = calculateAngle3D(
            pointA: leftHip.position,
            pointB: leftKnee.position,
            pointC: leftAnkle.position
        )
        let rightKneeAngle = calculateAngle3D(
            pointA: rightHip.position,
            pointB: rightKnee.position,
            pointC: rightAnkle.position
        )
        
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        
        // Store the calculated metrics - THIS WAS MISSING!
        metrics["avg_knee_angle"] = avgKneeAngle
        metrics["left_knee_angle"] = leftKneeAngle
        metrics["right_knee_angle"] = rightKneeAngle
        

        
        // Your existing range analysis
        switch avgKneeAngle {
        case 85...95:
            feedback.append("🏆 Perfect squat depth!")
        case 80...84, 96...105:
            feedback.append("✅ Great squat depth!")
            score -= 0.05
        // ... rest of your existing ranges
        default:
            if avgKneeAngle > 130 {
                feedback.append("🔽 Much deeper needed - bend those knees!")
                score -= 0.40
            } else {
                feedback.append("⬆️ Way too deep - ease up!")
                score -= 0.35
            }
        }
        

        
        return WorkoutAnalysis(
            exercise: .squat,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    // New 3D angle calculation
    private static func calculateAngle3D(pointA: simd_float4x4, pointB: simd_float4x4, pointC: simd_float4x4) -> Double {
        // Extract 3D positions from transformation matrices
        let posA = simd_float3(pointA.columns.3.x, pointA.columns.3.y, pointA.columns.3.z)
        let posB = simd_float3(pointB.columns.3.x, pointB.columns.3.y, pointB.columns.3.z)
        let posC = simd_float3(pointC.columns.3.x, pointC.columns.3.y, pointC.columns.3.z)
        
        // Calculate vectors
        let vectorBA = posA - posB
        let vectorBC = posC - posB
        
        // Calculate angle using dot product
        let dotProduct = simd_dot(vectorBA, vectorBC)
        let magnitudeBA = simd_length(vectorBA)
        let magnitudeBC = simd_length(vectorBC)
        
        let cosAngle = dotProduct / (magnitudeBA * magnitudeBC)
        let angleRadians = acos(max(-1, min(1, cosAngle)))
        
        return Double(angleRadians * 180.0 / Float.pi)
    }
    
    // MARK: - Push-up Analysis
    
    static func analyzePushUp(pose: VNHumanBodyPoseObservation) -> WorkoutAnalysis? {
        // Get required joints for push-up analysis
        guard let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let leftElbow = try? pose.recognizedPoint(.leftElbow),
              let rightElbow = try? pose.recognizedPoint(.rightElbow),
              let leftWrist = try? pose.recognizedPoint(.leftWrist),
              let rightWrist = try? pose.recognizedPoint(.rightWrist),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              // Check confidence
              leftShoulder.confidence > 0.5, rightShoulder.confidence > 0.5,
              leftElbow.confidence > 0.5, rightElbow.confidence > 0.5,
              leftWrist.confidence > 0.5, rightWrist.confidence > 0.5 else {
            return nil
        }
        
        let leftShoulderPoint = normalizePoint(leftShoulder.location)
        let rightShoulderPoint = normalizePoint(rightShoulder.location)
        let leftElbowPoint = normalizePoint(leftElbow.location)
        let rightElbowPoint = normalizePoint(rightElbow.location)
        let leftWristPoint = normalizePoint(leftWrist.location)
        let rightWristPoint = normalizePoint(rightWrist.location)
        let leftHipPoint = normalizePoint(leftHip.location)
        let rightHipPoint = normalizePoint(rightHip.location)
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // 1. Elbow angle analysis
        let leftElbowAngle = calculateAngle(
            pointA: leftShoulderPoint,
            pointB: leftElbowPoint,
            pointC: leftWristPoint
        )
        let rightElbowAngle = calculateAngle(
            pointA: rightShoulderPoint,
            pointB: rightElbowPoint,
            pointC: rightWristPoint
        )
        let avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2
        
        metrics["avg_elbow_angle"] = avgElbowAngle
        metrics["left_elbow_angle"] = leftElbowAngle
        metrics["right_elbow_angle"] = rightElbowAngle
        
        // 2. Body alignment (plank position)
        let bodyAlignment = calculateBodyAlignment(
            shoulder: CGPoint(x: (leftShoulderPoint.x + rightShoulderPoint.x) / 2,
                            y: (leftShoulderPoint.y + rightShoulderPoint.y) / 2),
            hip: CGPoint(x: (leftHipPoint.x + rightHipPoint.x) / 2,
                       y: (leftHipPoint.y + rightHipPoint.y) / 2)
        )
        metrics["body_alignment"] = bodyAlignment
        
        // Provide feedback based on elbow angle
        switch avgElbowAngle {
        case 70...90:
            feedback.append("🏆 Perfect push-up depth!")
        case 60...69, 91...110:
            feedback.append("✅ Good push-up form!")
            score -= 0.1
        case 110...130:
            feedback.append("🔽 Go deeper for full range")
            score -= 0.2
        default:
            if avgElbowAngle > 130 {
                feedback.append("🔽 Much deeper needed!")
                score -= 0.4
            } else {
                feedback.append("⬆️ Don't go too low")
                score -= 0.2
            }
        }
        
        // Body alignment feedback
        if bodyAlignment >= 160 {
            feedback.append("📐 Excellent body alignment!")
        } else if bodyAlignment >= 150 {
            feedback.append("📐 Good alignment - minor adjustment needed")
            score -= 0.1
        } else {
            feedback.append("📐 Keep body straight - avoid sagging hips")
            score -= 0.3
        }
        
        return WorkoutAnalysis(
            exercise: .pushUp,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    static func analyzePushUp3D(pose: VNHumanBodyPose3DObservation) -> WorkoutAnalysis? {
        guard let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let leftElbow = try? pose.recognizedPoint(.leftElbow),
              let rightElbow = try? pose.recognizedPoint(.rightElbow),
              let leftWrist = try? pose.recognizedPoint(.leftWrist),
              let rightWrist = try? pose.recognizedPoint(.rightWrist),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              pose.availableJointNames.contains(.leftShoulder),
              pose.availableJointNames.contains(.rightShoulder),
              pose.availableJointNames.contains(.leftElbow),
              pose.availableJointNames.contains(.rightElbow),
              pose.availableJointNames.contains(.leftWrist),
              pose.availableJointNames.contains(.rightWrist) else {
            return nil
        }
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // Calculate 3D elbow angles
        let leftElbowAngle = calculateAngle3D(
            pointA: leftShoulder.position,
            pointB: leftElbow.position,
            pointC: leftWrist.position
        )
        let rightElbowAngle = calculateAngle3D(
            pointA: rightShoulder.position,
            pointB: rightElbow.position,
            pointC: rightWrist.position
        )
        let avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2
        
        metrics["avg_elbow_angle"] = avgElbowAngle
        metrics["left_elbow_angle"] = leftElbowAngle
        metrics["right_elbow_angle"] = rightElbowAngle
        
        // Push-up depth feedback
        switch avgElbowAngle {
        case 70...90:
            feedback.append("🏆 Perfect push-up depth!")
        case 60...69, 91...110:
            feedback.append("✅ Good push-up form!")
            score -= 0.1
        default:
            if avgElbowAngle > 110 {
                feedback.append("🔽 Go deeper for full range")
                score -= 0.3
            } else {
                feedback.append("⬆️ Don't go too low")
                score -= 0.2
            }
        }
        
        return WorkoutAnalysis(
            exercise: .pushUp,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    // MARK: - Plank Analysis
    
    static func analyzePlank(pose: VNHumanBodyPoseObservation) -> WorkoutAnalysis? {
        guard let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              let leftAnkle = try? pose.recognizedPoint(.leftAnkle),
              let rightAnkle = try? pose.recognizedPoint(.rightAnkle),
              leftShoulder.confidence > 0.5, rightShoulder.confidence > 0.5,
              leftHip.confidence > 0.5, rightHip.confidence > 0.5,
              leftAnkle.confidence > 0.5, rightAnkle.confidence > 0.5 else {
            return nil
        }
        
        let leftShoulderPoint = normalizePoint(leftShoulder.location)
        let rightShoulderPoint = normalizePoint(rightShoulder.location)
        let leftHipPoint = normalizePoint(leftHip.location)
        let rightHipPoint = normalizePoint(rightHip.location)
        let leftAnklePoint = normalizePoint(leftAnkle.location)
        let rightAnklePoint = normalizePoint(rightAnkle.location)
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // Calculate hip angle (should be straight line)
        let hipAngle = calculatePlankHipAngle(
            shoulder: CGPoint(x: (leftShoulderPoint.x + rightShoulderPoint.x) / 2,
                            y: (leftShoulderPoint.y + rightShoulderPoint.y) / 2),
            hip: CGPoint(x: (leftHipPoint.x + rightHipPoint.x) / 2,
                       y: (leftHipPoint.y + rightHipPoint.y) / 2),
            ankle: CGPoint(x: (leftAnklePoint.x + rightAnklePoint.x) / 2,
                         y: (leftAnklePoint.y + rightAnklePoint.y) / 2)
        )
        
        metrics["hip_angle"] = hipAngle
        
        // Plank alignment feedback
        if hipAngle >= 160 && hipAngle <= 180 {
            feedback.append("🏆 Perfect plank alignment!")
        } else if hipAngle >= 150 {
            feedback.append("✅ Good alignment - minor adjustments")
            score -= 0.1
        } else if hipAngle >= 140 {
            feedback.append("📐 Keep hips level - avoid sagging")
            score -= 0.2
        } else {
            feedback.append("📐 Focus on straight line from head to heels")
            score -= 0.4
        }
        
        return WorkoutAnalysis(
            exercise: .plank,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    static func analyzePlank3D(pose: VNHumanBodyPose3DObservation) -> WorkoutAnalysis? {
        guard let leftShoulder = try? pose.recognizedPoint(.leftShoulder),
              let rightShoulder = try? pose.recognizedPoint(.rightShoulder),
              let leftHip = try? pose.recognizedPoint(.leftHip),
              let rightHip = try? pose.recognizedPoint(.rightHip),
              let leftAnkle = try? pose.recognizedPoint(.leftAnkle),
              let rightAnkle = try? pose.recognizedPoint(.rightAnkle),
              pose.availableJointNames.contains(.leftShoulder),
              pose.availableJointNames.contains(.rightShoulder),
              pose.availableJointNames.contains(.leftHip),
              pose.availableJointNames.contains(.rightHip),
              pose.availableJointNames.contains(.leftAnkle),
              pose.availableJointNames.contains(.rightAnkle) else {
            return nil
        }
        
        var feedback: [String] = []
        var score: Float = 1.0
        var metrics: [String: Double] = [:]
        
        // Calculate 3D hip alignment angle
        let shoulderMid = simd_float3(
            (leftShoulder.position.columns.3.x + rightShoulder.position.columns.3.x) / 2,
            (leftShoulder.position.columns.3.y + rightShoulder.position.columns.3.y) / 2,
            (leftShoulder.position.columns.3.z + rightShoulder.position.columns.3.z) / 2
        )
        let hipMid = simd_float3(
            (leftHip.position.columns.3.x + rightHip.position.columns.3.x) / 2,
            (leftHip.position.columns.3.y + rightHip.position.columns.3.y) / 2,
            (leftHip.position.columns.3.z + rightHip.position.columns.3.z) / 2
        )
        let ankleMid = simd_float3(
            (leftAnkle.position.columns.3.x + rightAnkle.position.columns.3.x) / 2,
            (leftAnkle.position.columns.3.y + rightAnkle.position.columns.3.y) / 2,
            (leftAnkle.position.columns.3.z + rightAnkle.position.columns.3.z) / 2
        )
        
        // Calculate hip angle for plank alignment
        let hipVector = hipMid - shoulderMid
        let ankleVector = ankleMid - hipMid
        let dotProduct = simd_dot(simd_normalize(hipVector), simd_normalize(ankleVector))
        let hipAngle = Double(acos(max(-1, min(1, dotProduct))) * 180.0 / Float.pi)
        
        metrics["hip_angle"] = hipAngle
        
        // Provide feedback
        if hipAngle >= 160 {
            feedback.append("🏆 Excellent plank alignment!")
        } else if hipAngle >= 150 {
            feedback.append("✅ Good alignment!")
            score -= 0.1
        } else {
            feedback.append("📐 Keep body straight - focus on alignment")
            score -= 0.3
        }
        
        return WorkoutAnalysis(
            exercise: .plank,
            score: max(0, score),
            feedback: feedback,
            metrics: metrics
        )
    }
    
    // MARK: - Helper Methods
    
    private static func calculateBodyAlignment(shoulder: CGPoint, hip: CGPoint) -> Double {
        let vector = CGPoint(x: hip.x - shoulder.x, y: hip.y - shoulder.y)
        let horizontalVector = CGPoint(x: 1, y: 0)
        
        let dotProduct = vector.x * horizontalVector.x + vector.y * horizontalVector.y
        let magnitude = sqrt(vector.x * vector.x + vector.y * vector.y)
        let cosAngle = dotProduct / magnitude
        
        return _math.acos(max(-1, min(1, cosAngle))) * 180.0 / Double.pi
    }
    
    private static func calculatePlankHipAngle(shoulder: CGPoint, hip: CGPoint, ankle: CGPoint) -> Double {
        let shoulderToHip = CGPoint(x: hip.x - shoulder.x, y: hip.y - shoulder.y)
        let hipToAnkle = CGPoint(x: ankle.x - hip.x, y: ankle.y - hip.y)
        
        let dotProduct = shoulderToHip.x * hipToAnkle.x + shoulderToHip.y * hipToAnkle.y
        let magnitudeA = sqrt(shoulderToHip.x * shoulderToHip.x + shoulderToHip.y * shoulderToHip.y)
        let magnitudeB = sqrt(hipToAnkle.x * hipToAnkle.x + hipToAnkle.y * hipToAnkle.y)
        
        let cosAngle = dotProduct / (magnitudeA * magnitudeB)
        let angleRadians = acos(max(-1, min(1, cosAngle)))
        
        return angleRadians * 180.0 / Double.pi
    }
}

// MARK: - Analysis Result
struct WorkoutAnalysis {
    let exercise: WorkoutType
    let score: Float
    let feedback: [String]
    let metrics: [String: Double]
    let timestamp = Date()
}
