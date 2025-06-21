import Foundation
import AVFoundation
import Vision
import CoreImage

class VideoAnalyzer {
    
    func analyzeVideo(
        url: URL, 
        workoutType: WorkoutType,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> [WorkoutAnalysis] {
        
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        _ = CMTimeGetSeconds(duration)
        
        // Generate frames from video
        let frameAnalyses = try await extractAndAnalyzeFrames(
            from: asset,
            workoutType: workoutType,
            progressCallback: progressCallback
        )
        
        // Detect reps and analyze motion
        let repAnalyses = detectReps(from: frameAnalyses, workoutType: workoutType)
        
        return repAnalyses
    }
    
    private func extractAndAnalyzeFrames(
        from asset: AVAsset,
        workoutType: WorkoutType,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> [FrameAnalysis] {
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let duration = try await asset.load(.duration)
        let fps = 5 // Analyze 5 frames per second
        let frameInterval = 1.0 / Double(fps)
        
        var frameAnalyses: [FrameAnalysis] = []
        var currentTime: Double = 0
        
        while currentTime < CMTimeGetSeconds(duration) {
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
            
            do {
                let cgImage = try await generator.image(at: time).image
                
                // Analyze pose in this frame
                if let analysis = try await analyzePoseInFrame(cgImage, workoutType: workoutType) {
                    let frameAnalysis = FrameAnalysis(
                        timestamp: currentTime,
                        poseAnalysis: analysis
                    )
                    frameAnalyses.append(frameAnalysis)
                }
                
                // Update progress
                let progress = currentTime / CMTimeGetSeconds(duration) * 0.8 // 80% for frame extraction
                await MainActor.run {
                    progressCallback(progress)
                }
                
            } catch {
                print("Failed to generate frame at \(currentTime)s: \(error)")
            }
            
            currentTime += frameInterval
        }
        
        return frameAnalyses
    }
    
    private func analyzePoseInFrame(_ image: CGImage, workoutType: WorkoutType) async throws -> WorkoutAnalysis? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorkoutAnalysis?, Error>) in
            // Try 3D pose detection first, fallback to 2D
            let request3D = VNDetectHumanBodyPose3DRequest { request, error in
                if error != nil {
                    // Fallback to 2D
                    self.analyze2DPose(image: image, workoutType: workoutType) { result in
                        continuation.resume(returning: result)
                    }
                    return
                }
                
                guard let results = request.results as? [VNHumanBodyPose3DObservation],
                      let pose = results.first else {
                    // Fallback to 2D
                    self.analyze2DPose(image: image, workoutType: workoutType) { result in
                        continuation.resume(returning: result)
                    }
                    return
                }
                
                // Analyze with 3D pose
                let analysis = self.analyzePose3D(pose: pose, workoutType: workoutType)
                continuation.resume(returning: analysis)
            }
            
            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request3D])
            } catch {
                // Fallback to 2D on any error
                self.analyze2DPose(image: image, workoutType: workoutType) { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func analyze2DPose(image: CGImage, workoutType: WorkoutType, completion: @escaping (WorkoutAnalysis?) -> Void) {
        let request = VNDetectHumanBodyPoseRequest { request, error in
            if error != nil {
                completion(nil)
                return
            }
            
            guard let results = request.results as? [VNHumanBodyPoseObservation],
                  let pose = results.first else {
                completion(nil)
                return
            }
            
            let analysis = self.analyzePose2D(pose: pose, workoutType: workoutType)
            completion(analysis)
        }
        
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }
    
    // MARK: - Exercise-specific analyzers
    
    private func analyzePose3D(pose: VNHumanBodyPose3DObservation, workoutType: WorkoutType) -> WorkoutAnalysis? {
        switch workoutType {
        case .squat:
            return PoseAnalyzer.analyzeSquat3D(pose: pose)
        case .pushUp:
            return PoseAnalyzer.analyzePushUp3D(pose: pose)
        case .plank:
            return PoseAnalyzer.analyzePlank3D(pose: pose)
        }
    }
    
    private func analyzePose2D(pose: VNHumanBodyPoseObservation, workoutType: WorkoutType) -> WorkoutAnalysis? {
        switch workoutType {
        case .squat:
            return PoseAnalyzer.analyzeSquat(pose: pose)
        case .pushUp:
            return PoseAnalyzer.analyzePushUp(pose: pose)
        case .plank:
            return PoseAnalyzer.analyzePlank(pose: pose)
        }
    }
    
    private func detectReps(from frameAnalyses: [FrameAnalysis], workoutType: WorkoutType) -> [WorkoutAnalysis] {
        guard !frameAnalyses.isEmpty else { return [] }
        
        switch workoutType {
        case .squat:
            return detectSquatReps(from: frameAnalyses)
        case .pushUp:
            return detectPushUpReps(from: frameAnalyses)
        case .plank:
            return detectPlankSessions(from: frameAnalyses)
        }
    }
    
    private func detectSquatReps(from frameAnalyses: [FrameAnalysis]) -> [WorkoutAnalysis] {
        var reps: [WorkoutAnalysis] = []
        var repFrames: [FrameAnalysis] = []
        var isInSquat = false
        var lastKneeAngle: Double = 180
        
        for frame in frameAnalyses {
            guard let analysis = frame.poseAnalysis,
                  let kneeAngle = analysis.metrics["avg_knee_angle"] else {
                continue
            }
            
            // Detect squat start (going down)
            if !isInSquat && kneeAngle < 130 && lastKneeAngle - kneeAngle > 5 {
                isInSquat = true
                repFrames = [frame]
            }
            // Continue tracking the rep
            else if isInSquat {
                repFrames.append(frame)
                
                // Detect squat end (coming back up)
                if kneeAngle > 160 && kneeAngle - lastKneeAngle > 10 {
                    // Analyze the complete rep
                    if let repAnalysis = analyzeCompleteRep(frames: repFrames) {
                        reps.append(repAnalysis)
                    }
                    
                    isInSquat = false
                    repFrames = []
                }
            }
            
            lastKneeAngle = kneeAngle
        }
        
        // Handle incomplete rep at the end
        if !repFrames.isEmpty, let repAnalysis = analyzeCompleteRep(frames: repFrames) {
            reps.append(repAnalysis)
        }
        
        return reps
    }
    
    private func detectPushUpReps(from frameAnalyses: [FrameAnalysis]) -> [WorkoutAnalysis] {
        var reps: [WorkoutAnalysis] = []
        var repFrames: [FrameAnalysis] = []
        var isInPushUp = false
        var lastElbowAngle: Double = 180
        
        for frame in frameAnalyses {
            guard let analysis = frame.poseAnalysis,
                  let elbowAngle = analysis.metrics["avg_elbow_angle"] else {
                continue
            }
            
            // Detect push-up start (going down)
            if !isInPushUp && elbowAngle < 150 && lastElbowAngle - elbowAngle > 5 {
                isInPushUp = true
                repFrames = [frame]
            }
            // Continue tracking the rep
            else if isInPushUp {
                repFrames.append(frame)
                
                // Detect push-up end (coming back up)
                if elbowAngle > 160 && elbowAngle - lastElbowAngle > 10 {
                    if let repAnalysis = analyzeCompleteRep(frames: repFrames) {
                        reps.append(repAnalysis)
                    }
                    
                    isInPushUp = false
                    repFrames = []
                }
            }
            
            lastElbowAngle = elbowAngle
        }
        
        // Handle incomplete rep at the end
        if !repFrames.isEmpty, let repAnalysis = analyzeCompleteRep(frames: repFrames) {
            reps.append(repAnalysis)
        }
        
        return reps
    }
    
    private func detectPlankSessions(from frameAnalyses: [FrameAnalysis]) -> [WorkoutAnalysis] {
        // For plank, analyze the entire session as one "rep"
        guard !frameAnalyses.isEmpty else { return [] }
        
        let analyses = frameAnalyses.compactMap { $0.poseAnalysis }
        guard !analyses.isEmpty else { return [] }
        
        // Calculate session metrics
        let avgScore = analyses.map { $0.score }.reduce(0, +) / Float(analyses.count)
        let sessionDuration = frameAnalyses.last!.timestamp - frameAnalyses.first!.timestamp
        
        var feedback: [String] = []
        var metrics: [String: Double] = [:]
        
        // Analyze plank stability and duration
        let hipAngles = analyses.compactMap { $0.metrics["hip_angle"] }
        let avgHipAngle = hipAngles.isEmpty ? 180.0 : hipAngles.reduce(0, +) / Double(hipAngles.count)
        
        metrics["session_duration"] = sessionDuration
        metrics["avg_hip_angle"] = avgHipAngle
        metrics["stability_score"] = Double(avgScore * 100)
        
        // Generate feedback based on duration and form
        if sessionDuration >= 60 {
            feedback.append("🏆 Excellent plank duration!")
        } else if sessionDuration >= 30 {
            feedback.append("💪 Good plank hold!")
        } else {
            feedback.append("⏱️ Try to hold longer next time")
        }
        
        if avgHipAngle >= 160 && avgHipAngle <= 180 {
            feedback.append("📐 Great plank alignment!")
        } else {
            feedback.append("📐 Focus on keeping a straight line")
        }
        
        let sessionAnalysis = WorkoutAnalysis(
            exercise: .plank,
            score: avgScore,
            feedback: feedback,
            metrics: metrics
        )
        
        return [sessionAnalysis]
    }
    
    private func analyzeCompleteRep(frames: [FrameAnalysis]) -> WorkoutAnalysis? {
        guard !frames.isEmpty else { return nil }
        
        let analyses = frames.compactMap { $0.poseAnalysis }
        guard !analyses.isEmpty else { return nil }
        
        // Calculate metrics across the rep
        let scores = analyses.map { $0.score }
        let avgScore = scores.reduce(0, +) / Float(scores.count)
        let minScore = scores.min() ?? 0
        let maxScore = scores.max() ?? 0
        
        // Depth analysis
        let kneeAngles = analyses.compactMap { $0.metrics["avg_knee_angle"] }
        let deepestAngle = kneeAngles.min() ?? 180
        let highestAngle = kneeAngles.max() ?? 180
        let depthRange = highestAngle - deepestAngle
        
        // Consistency analysis
        let angleVariation = calculateVariation(kneeAngles)
        
        // Tempo analysis
        let repDuration = frames.last!.timestamp - frames.first!.timestamp
        let tempoFeedback = analyzeRepTempo(duration: repDuration)
        
        // Generate comprehensive feedback
        var enhancedFeedback: [String] = []
        
        // 1. Overall performance
        if avgScore >= 0.9 {
            enhancedFeedback.append("🏆 Excellent rep! Nearly perfect form")
        } else if avgScore >= 0.75 {
            enhancedFeedback.append("💪 Great rep! Strong technique")
        } else if avgScore >= 0.6 {
            enhancedFeedback.append("👍 Good rep with room for improvement")
        } else {
            enhancedFeedback.append("⚠️ Focus needed - let's improve this form")
        }
        
        // 2. Depth feedback
        if deepestAngle <= 85 {
            enhancedFeedback.append("🎯 Perfect squat depth achieved!")
        } else if deepestAngle <= 95 {
            enhancedFeedback.append("✅ Good depth - you're in the ideal range")
        } else if deepestAngle <= 110 {
            enhancedFeedback.append("📐 Decent depth - try going 5-10° deeper")
        } else if deepestAngle <= 130 {
            enhancedFeedback.append("🔽 Need more depth - focus on sitting back more")
        } else {
            enhancedFeedback.append("⚠️ Much deeper needed - barely a quarter squat")
        }
        
        // 3. Consistency feedback
        if angleVariation < 5 {
            enhancedFeedback.append("🎯 Consistent motion throughout rep")
        } else if angleVariation < 10 {
            enhancedFeedback.append("📊 Fairly consistent - minor fluctuations")
        } else {
            enhancedFeedback.append("📈 Work on smoother, more controlled movement")
        }
        
        // 4. Range of motion
        if depthRange >= 80 {
            enhancedFeedback.append("🔄 Excellent range of motion")
        } else if depthRange >= 60 {
            enhancedFeedback.append("📏 Good range of motion")
        } else {
            enhancedFeedback.append("📐 Try for greater range of motion")
        }
        
        // 5. Tempo feedback
        enhancedFeedback.append(tempoFeedback)
        
        // Combine all unique original feedback
        let originalFeedback = Array(Set(analyses.flatMap { $0.feedback }))
        enhancedFeedback.append(contentsOf: originalFeedback.filter { feedback in
            !enhancedFeedback.contains { $0.contains(feedback.dropFirst(2)) } // Avoid duplicates
        })
        
        // Enhanced metrics
        var combinedMetrics: [String: Double] = [:]
        for analysis in analyses {
            for (key, value) in analysis.metrics {
                combinedMetrics[key] = (combinedMetrics[key] ?? 0) + value / Double(analyses.count)
            }
        }
        
        // Add new comprehensive metrics
        combinedMetrics["deepest_angle"] = deepestAngle
        combinedMetrics["highest_angle"] = highestAngle
        combinedMetrics["range_of_motion"] = depthRange
        combinedMetrics["rep_duration"] = repDuration
        combinedMetrics["consistency_score"] = max(0, 100 - angleVariation * 10)
        combinedMetrics["min_score"] = Double(minScore)
        combinedMetrics["max_score"] = Double(maxScore)
        combinedMetrics["score_variation"] = Double(maxScore - minScore)
        
        return WorkoutAnalysis(
            exercise: .squat,
            score: avgScore,
            feedback: enhancedFeedback,
            metrics: combinedMetrics
        )
    }
    
    private func calculateVariation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func analyzeRepTempo(duration: Double) -> String {
        switch duration {
        case 0..<1.5:
            return "⚡ Very fast rep - slow down for better control"
        case 1.5..<2.5:
            return "🏃 Fast rep - consider slightly slower tempo"
        case 2.5..<4.0:
            return "⏱️ Good tempo - well controlled"
        case 4.0..<6.0:
            return "🐌 Slower tempo - good for strength building"
        default:
            return "⏳ Very slow rep - might be too slow for most goals"
        }
    }
}

// MARK: - Supporting Types
struct FrameAnalysis {
    let timestamp: Double
    let poseAnalysis: WorkoutAnalysis?
} 
