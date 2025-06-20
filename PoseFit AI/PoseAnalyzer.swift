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
        
        // 1. KNEE DEPTH ANALYSIS (using normalized coordinates)
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
        
        // Depth feedback
        if avgKneeAngle > 120 {
            feedback.append("🔽 Go deeper - aim for 90° knee bend")
            score -= 0.4
        } else if avgKneeAngle < 70 {
            feedback.append("⬆️ Too deep - come up slightly")
            score -= 0.2
        } else if avgKneeAngle <= 90 {
            feedback.append("✅ Perfect squat depth!")
        } else {
            feedback.append("👍 Good depth - try to go a bit deeper")
            score -= 0.1
        }
        
        // 2. KNEE SYMMETRY
        let kneeAngleDiff = abs(leftKneeAngle - rightKneeAngle)
        metrics["knee_symmetry"] = kneeAngleDiff
        
        if kneeAngleDiff > 15 {
            feedback.append("⚖️ Keep both legs even - balance your weight")
            score -= 0.3
        }
        
        // 3. TORSO POSTURE (using shoulders and hips)
        let torsoAngle = calculateTorsoAngle(
            leftShoulder: leftShoulderPoint,
            rightShoulder: rightShoulderPoint,
            leftHip: leftHipPoint,
            rightHip: rightHipPoint
        )
        metrics["torso_angle"] = torsoAngle
        
        if torsoAngle > 45 {
            feedback.append("📐 Keep your chest up - don't lean too far forward")
            score -= 0.3
        } else if torsoAngle < 15 {
            feedback.append("📐 Lean forward slightly - engage your core")
            score -= 0.2
        }
        
        // 4. KNEE TRACKING (knees over toes)
        let leftKneeTracking = leftKneePoint.x - leftAnklePoint.x
        let rightKneeTracking = rightKneePoint.x - rightAnklePoint.x
        
        if abs(leftKneeTracking) > 0.1 || abs(rightKneeTracking) > 0.1 {
            feedback.append("🦵 Keep knees aligned over your toes")
            score -= 0.2
        }
        
        // 5. OVERALL SCORE FEEDBACK
        if score >= 0.9 {
            feedback.insert("🏆 Excellent squat form!", at: 0)
        } else if score >= 0.7 {
            feedback.insert("💪 Good squat - minor improvements needed", at: 0)
        } else if score >= 0.5 {
            feedback.insert("⚠️ Form needs attention", at: 0)
        } else {
            feedback.insert("🚨 Focus on form corrections", at: 0)
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
}

// MARK: - Analysis Result
struct WorkoutAnalysis {
    let exercise: WorkoutType
    let score: Float
    let feedback: [String]
    let metrics: [String: Double]
    let timestamp = Date()
}
