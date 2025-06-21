import SwiftUI
import PhotosUI
import AVFoundation

struct VideoUploadView: View {
    @Binding var isPresented: Bool
    let workoutType: WorkoutType
    
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var isProcessing = false
    @State private var analysisResults: [WorkoutAnalysis] = []
    @State private var showResults = false
    @State private var processingProgress: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isProcessing {
                    processingView
                } else if showResults {
                    resultsView
                } else {
                    uploadView
                }
            }
            .navigationTitle("\(workoutType.displayName) Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var uploadView: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "video.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Upload Your \(workoutType.displayName) Video")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Record or select a video showing your form. We'll analyze your technique and provide personalized feedback.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Video preview (if selected)
            if let videoURL = videoURL {
                VideoPlayerView(url: videoURL)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            
            // Action buttons
            VStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedVideo,
                    matching: .videos
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Select from Photos")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal)
                
                if videoURL != nil {
                    Button(action: analyzeVideo) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Analyze Form")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Tips for best results:")
                    .font(.headline)
                
                Text("• Film from the side view")
                Text("• Make sure your full body is visible")
                Text("• Use good lighting")
                
                switch workoutType {
                case .squat:
                    Text("• Perform 3-5 reps for better analysis")
                case .pushUp:
                    Text("• Perform 3-5 push-ups for better analysis")
                case .plank:
                    Text("• Hold plank for at least 15-30 seconds")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .onChange(of: selectedVideo) { _, newItem in
            loadVideo(from: newItem)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 30) {
            ProgressView(value: processingProgress)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2.0)
            
            Text("Analyzing your form...")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This may take a few moments")
                .foregroundColor(.secondary)
            
            ProgressView(value: processingProgress) {
                Text("\(Int(processingProgress * 100))% Complete")
                    .font(.caption)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("🎯 Analysis Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                

                
                // Overall Performance Summary
                if !analysisResults.isEmpty {
                    let avgScore = analysisResults.map(\.score).reduce(0, +) / Float(analysisResults.count)
                    OverallPerformanceCard(
                        score: avgScore,
                        totalReps: analysisResults.count,
                        analyses: analysisResults
                    )
                } else {
                    // Show message when no reps detected
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(workoutType == .plank ? "No Session Detected" : "No Reps Detected")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(getNoRepsMessage(for: workoutType))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Key Insights
                if !analysisResults.isEmpty {
                    KeyInsightsCard(analyses: analysisResults, workoutType: workoutType)
                }
                
                // Performance Metrics
                if !analysisResults.isEmpty {
                    PerformanceMetricsCard(analyses: analysisResults, workoutType: workoutType)
                }
                
                // Rep-by-rep analysis
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rep-by-Rep Breakdown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(Array(analysisResults.enumerated()), id: \.offset) { index, analysis in
                            EnhancedAnalysisResultCard(repNumber: index + 1, analysis: analysis)
                        }
                    }
                }
                
                // Action Recommendations
                if !analysisResults.isEmpty {
                    RecommendationsCard(analyses: analysisResults, workoutType: workoutType)
                }
                
                // Try Again button
                Button("Analyze Another Video") {
                    resetView()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .fontWeight(.semibold)
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: VideoFile.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let videoFile):
                    if let videoFile = videoFile {
                        self.videoURL = videoFile.url
                    }
                case .failure(let error):
                    print("Failed to load video: \(error)")
                }
            }
        }
    }
    
    private func analyzeVideo() {
        guard let videoURL = videoURL else { return }
        
        isProcessing = true
        processingProgress = 0
        
        Task {
            do {
                let analyzer = VideoAnalyzer()
                let results = try await analyzer.analyzeVideo(url: videoURL, workoutType: workoutType) { progress in
                    DispatchQueue.main.async {
                        self.processingProgress = progress
                    }
                }
                
                DispatchQueue.main.async {
                    self.analysisResults = results
                    self.isProcessing = false
                    self.showResults = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    print("Analysis failed: \(error)")
                }
            }
        }
    }
    
    private func resetView() {
        videoURL = nil
        selectedVideo = nil
        analysisResults = []
        showResults = false
        processingProgress = 0
    }
    
    private func getNoRepsMessage(for workoutType: WorkoutType) -> String {
        switch workoutType {
        case .squat:
            return "The video might be too short, unclear, or the squats weren't deep enough to detect. Try recording a video with 3-5 clear squat reps."
        case .pushUp:
            return "The video might be too short, unclear, or the push-ups weren't deep enough to detect. Try recording a video with 3-5 clear push-up reps."
        case .plank:
            return "The video might be too short or unclear to detect a plank position. Try recording a video showing you holding a plank for at least 15 seconds."
        }
    }
}

// MARK: - Supporting Views
struct VideoPlayerView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        // Auto-layout the player layer
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Enhanced Result Cards

struct OverallPerformanceCard: View {
    let score: Float
    let totalReps: Int
    let analyses: [WorkoutAnalysis]
    
    var body: some View {
        VStack(spacing: 16) {
            // Main score
            VStack {
                Text("Overall Form Score")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(score * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(score > 0.7 ? .green : score > 0.5 ? .orange : .red)
            }
            
            // Session summary
            HStack(spacing: 20) {
                VStack {
                    Text("\(totalReps)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Reps Analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    let bestScore = analyses.map(\.score).max() ?? 0
                    Text("\(Int(bestScore * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Best Rep")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    let consistency = calculateConsistencyScore(analyses: analyses)
                    Text("\(Int(consistency))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Consistency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func calculateConsistencyScore(analyses: [WorkoutAnalysis]) -> Float {
        guard analyses.count > 1 else { return 100 }
        
        let scores = analyses.map { $0.score }
        let mean = scores.reduce(0, +) / Float(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(scores.count)
        let consistency = max(0, 100 - sqrt(variance) * 100)
        
        return consistency
    }
}

struct KeyInsightsCard: View {
    let analyses: [WorkoutAnalysis]
    let workoutType: WorkoutType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔍 Key Insights")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                switch workoutType {
                case .squat:
                    squatInsights()
                case .pushUp:
                    pushUpInsights()
                case .plank:
                    plankInsights()
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func squatInsights() -> some View {
        // Knee angle depth
        let kneeAngles = analyses.compactMap { $0.metrics["avg_knee_angle"] }
        if !kneeAngles.isEmpty {
            let avgDepth = kneeAngles.reduce(0, +) / Double(kneeAngles.count)
            InsightRow(
                icon: "📐",
                title: "Average Depth",
                value: "\(Int(avgDepth))°",
                insight: squatDepthInsight(for: avgDepth)
            )
        }
        
        // Range of motion
        if !kneeAngles.isEmpty {
            let maxAngle = kneeAngles.max() ?? 0
            let minAngle = kneeAngles.min() ?? 180
            let range = maxAngle - minAngle
            InsightRow(
                icon: "🔄",
                title: "Range of Motion",
                value: "\(Int(range))°",
                insight: rangeInsight(for: range)
            )
        }
        
        // Symmetry check
        let leftAngles = analyses.compactMap { $0.metrics["left_knee_angle"] }
        let rightAngles = analyses.compactMap { $0.metrics["right_knee_angle"] }
        if !leftAngles.isEmpty && !rightAngles.isEmpty {
            let differences = zip(leftAngles, rightAngles).map { abs($0 - $1) }
            let totalDifference = differences.reduce(0, +)
            let avgDifference = totalDifference / Double(leftAngles.count)
            InsightRow(
                icon: "⚖️",
                title: "Symmetry",
                value: "\(String(format: "%.1f", avgDifference))°",
                insight: symmetryInsight(for: avgDifference)
            )
        }
    }
    
    @ViewBuilder
    private func pushUpInsights() -> some View {
        // Elbow angle depth
        let elbowAngles = analyses.compactMap { $0.metrics["avg_elbow_angle"] }
        if !elbowAngles.isEmpty {
            let avgDepth = elbowAngles.reduce(0, +) / Double(elbowAngles.count)
            InsightRow(
                icon: "💪",
                title: "Average Depth",
                value: "\(Int(avgDepth))°",
                insight: pushUpDepthInsight(for: avgDepth)
            )
        }
        
        // Body alignment
        let alignments = analyses.compactMap { $0.metrics["body_alignment"] }
        if !alignments.isEmpty {
            let avgAlignment = alignments.reduce(0, +) / Double(alignments.count)
            InsightRow(
                icon: "📐",
                title: "Body Alignment",
                value: "\(Int(avgAlignment))°",
                insight: alignmentInsight(for: avgAlignment)
            )
        }
        
        // Symmetry check
        let leftAngles = analyses.compactMap { $0.metrics["left_elbow_angle"] }
        let rightAngles = analyses.compactMap { $0.metrics["right_elbow_angle"] }
        if !leftAngles.isEmpty && !rightAngles.isEmpty {
            let differences = zip(leftAngles, rightAngles).map { abs($0 - $1) }
            let totalDifference = differences.reduce(0, +)
            let avgDifference = totalDifference / Double(leftAngles.count)
            InsightRow(
                icon: "⚖️",
                title: "Arm Symmetry",
                value: "\(String(format: "%.1f", avgDifference))°",
                insight: symmetryInsight(for: avgDifference)
            )
        }
    }
    
    @ViewBuilder
    private func plankInsights() -> some View {
        if let sessionAnalysis = analyses.first {
            // Duration
            if let duration = sessionAnalysis.metrics["session_duration"] {
                InsightRow(
                    icon: "⏱️",
                    title: "Hold Duration",
                    value: "\(Int(duration))s",
                    insight: plankDurationInsight(for: duration)
                )
            }
            
            // Hip alignment
            if let hipAngle = sessionAnalysis.metrics["avg_hip_angle"] {
                InsightRow(
                    icon: "📐",
                    title: "Body Alignment",
                    value: "\(Int(hipAngle))°",
                    insight: plankAlignmentInsight(for: hipAngle)
                )
            }
            
            // Stability score
            if let stability = sessionAnalysis.metrics["stability_score"] {
                InsightRow(
                    icon: "🎯",
                    title: "Stability",
                    value: "\(Int(stability))%",
                    insight: stabilityInsight(for: stability)
                )
            }
        }
    }
    
    // Squat-specific insights
    private func squatDepthInsight(for depth: Double) -> String {
        switch depth {
        case 80...95: return "Excellent depth!"
        case 96...110: return "Good depth range"
        case 111...130: return "Could go deeper"
        default: return depth > 130 ? "Focus on more depth" : "Too deep"
        }
    }
    
    // Push-up specific insights
    private func pushUpDepthInsight(for depth: Double) -> String {
        switch depth {
        case 70...90: return "Perfect depth!"
        case 60...69, 91...110: return "Good range"
        case 111...130: return "Go deeper"
        default: return depth > 130 ? "Much deeper needed" : "Don't go too low"
        }
    }
    
    private func alignmentInsight(for alignment: Double) -> String {
        switch alignment {
        case 160...: return "Excellent alignment"
        case 150...159: return "Good alignment"
        case 140...149: return "Minor adjustments"
        default: return "Focus on form"
        }
    }
    
    // Plank-specific insights
    private func plankDurationInsight(for duration: Double) -> String {
        switch duration {
        case 60...: return "Excellent endurance!"
        case 30...59: return "Good hold time"
        case 15...29: return "Building strength"
        default: return "Keep practicing"
        }
    }
    
    private func plankAlignmentInsight(for angle: Double) -> String {
        switch angle {
        case 160...180: return "Perfect alignment!"
        case 150...159: return "Good form"
        case 140...149: return "Minor adjustments"
        default: return "Focus on straight line"
        }
    }
    
    private func stabilityInsight(for stability: Double) -> String {
        switch stability {
        case 85...: return "Rock solid!"
        case 70...84: return "Very stable"
        case 55...69: return "Good control"
        default: return "Work on stability"
        }
    }
    
    private func rangeInsight(for range: Double) -> String {
        switch range {
        case 80...: return "Excellent mobility"
        case 60...79: return "Good range"
        case 40...59: return "Limited range"
        default: return "Work on flexibility"
        }
    }
    
    private func symmetryInsight(for difference: Double) -> String {
        switch difference {
        case 0...5: return "Perfect symmetry"
        case 6...10: return "Good balance"
        case 11...15: return "Minor imbalance"
        default: return "Work on symmetry"
        }
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let insight: String
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(insight)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceMetricsCard: View {
    let analyses: [WorkoutAnalysis]
    let workoutType: WorkoutType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Performance Metrics")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Common metrics
                MetricTile(
                    title: "Best Score",
                    value: "\(Int((analyses.map(\.score).max() ?? 0) * 100))%",
                    color: .green
                )
                
                // Exercise-specific metrics
                switch workoutType {
                case .squat:
                    MetricTile(
                        title: "Deepest Squat",
                        value: "\(Int(analyses.compactMap { $0.metrics["avg_knee_angle"] }.min() ?? 180))°",
                        color: .blue
                    )
                case .pushUp:
                    MetricTile(
                        title: "Deepest Push-up",
                        value: "\(Int(analyses.compactMap { $0.metrics["avg_elbow_angle"] }.min() ?? 180))°",
                        color: .blue
                    )
                case .plank:
                    if let duration = analyses.first?.metrics["session_duration"] {
                        MetricTile(
                            title: "Hold Duration",
                            value: "\(Int(duration))s",
                            color: .blue
                        )
                    }
                }
                
                // Consistency (for squat and push-up)
                if workoutType != .plank && analyses.count > 1 {
                    let consistency = calculateConsistency(analyses: analyses)
                    MetricTile(
                        title: "Consistency",
                        value: "\(Int(consistency))%",
                        color: .purple
                    )
                } else if workoutType == .plank {
                    if let stability = analyses.first?.metrics["stability_score"] {
                        MetricTile(
                            title: "Stability",
                            value: "\(Int(stability))%",
                            color: .purple
                        )
                    }
                }
                
                // Duration/count
                if workoutType != .plank {
                    MetricTile(
                        title: "Total Reps",
                        value: "\(analyses.count)",
                        color: .orange
                    )
                } else {
                    if let avgAlignment = analyses.first?.metrics["avg_hip_angle"] {
                        MetricTile(
                            title: "Alignment",
                            value: "\(Int(avgAlignment))°",
                            color: .orange
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func calculateConsistency(analyses: [WorkoutAnalysis]) -> Float {
        guard analyses.count > 1 else { return 100 }
        
        let scores = analyses.map { $0.score }
        let mean = scores.reduce(0, +) / Float(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(scores.count)
        let consistency = max(0, 100 - sqrt(variance) * 100)
        
        return consistency
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct RecommendationsCard: View {
    let analyses: [WorkoutAnalysis]
    let workoutType: WorkoutType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 Recommendations")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                let recommendations = generateRecommendations(from: analyses, workoutType: workoutType)
                ForEach(recommendations.indices, id: \.self) { index in
                    RecommendationRow(
                        priority: index + 1,
                        recommendation: recommendations[index]
                    )
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func generateRecommendations(from analyses: [WorkoutAnalysis], workoutType: WorkoutType) -> [String] {
        var recommendations: [String] = []
        let avgScore = analyses.map(\.score).reduce(0, +) / Float(analyses.count)
        
        switch workoutType {
        case .squat:
            let kneeAngles = analyses.compactMap { $0.metrics["avg_knee_angle"] }
            if !kneeAngles.isEmpty {
                let avgDepth = kneeAngles.reduce(0, +) / Double(kneeAngles.count)
                
                if avgDepth > 130 {
                    recommendations.append("Focus on going deeper - aim for 90° knee angle")
                } else if avgDepth < 80 {
                    recommendations.append("Don't go too deep - aim for parallel thighs")
                }
                
                // Check symmetry
                let leftAngles = analyses.compactMap { $0.metrics["left_knee_angle"] }
                let rightAngles = analyses.compactMap { $0.metrics["right_knee_angle"] }
                if !leftAngles.isEmpty && !rightAngles.isEmpty {
                    let differences = zip(leftAngles, rightAngles).map { abs($0 - $1) }
                    let totalDifference = differences.reduce(0, +)
                    let avgDifference = totalDifference / Double(leftAngles.count)
                    if avgDifference > 10 {
                        recommendations.append("Work on balanced form - one leg deeper than other")
                    }
                }
            }
            
        case .pushUp:
            let elbowAngles = analyses.compactMap { $0.metrics["avg_elbow_angle"] }
            if !elbowAngles.isEmpty {
                let avgDepth = elbowAngles.reduce(0, +) / Double(elbowAngles.count)
                
                if avgDepth > 130 {
                    recommendations.append("Go deeper - chest should nearly touch the ground")
                } else if avgDepth < 60 {
                    recommendations.append("Don't go too low - maintain control")
                }
                
                // Check body alignment
                let alignments = analyses.compactMap { $0.metrics["body_alignment"] }
                if !alignments.isEmpty {
                    let avgAlignment = alignments.reduce(0, +) / Double(alignments.count)
                    if avgAlignment < 150 {
                        recommendations.append("Keep body straight - engage core to prevent sagging")
                    }
                }
            }
            
        case .plank:
            if let sessionAnalysis = analyses.first {
                if let duration = sessionAnalysis.metrics["session_duration"] {
                    if duration < 30 {
                        recommendations.append("Build endurance - aim for 30+ second holds")
                    } else if duration < 60 {
                        recommendations.append("Great progress! Work toward 60-second holds")
                    }
                }
                
                if let hipAngle = sessionAnalysis.metrics["avg_hip_angle"] {
                    if hipAngle < 150 {
                        recommendations.append("Keep hips level - imagine a straight line from head to heels")
                    }
                }
            }
        }
        
        // Common recommendations based on overall performance
        if avgScore < 0.6 {
            switch workoutType {
            case .squat:
                recommendations.append("Practice bodyweight squats to improve form")
            case .pushUp:
                recommendations.append("Try wall or knee push-ups to build strength")
            case .plank:
                recommendations.append("Start with shorter holds and focus on form")
            }
            recommendations.append("Consider working with a trainer for technique refinement")
        } else if avgScore > 0.8 {
            // Suggest progressions for good performers
            switch workoutType {
            case .squat:
                recommendations.append("Great form! Try adding weight or single-leg squats")
            case .pushUp:
                recommendations.append("Excellent! Try diamond push-ups or add elevation")
            case .plank:
                recommendations.append("Amazing stability! Try side planks or dynamic variations")
            }
        }
        
        return Array(recommendations.prefix(3)) // Top 3 recommendations
    }
}

struct RecommendationRow: View {
    let priority: Int
    let recommendation: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(priority)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(recommendation)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct EnhancedAnalysisResultCard: View {
    let repNumber: Int
    let analysis: WorkoutAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with score
            HStack {
                VStack(alignment: .leading) {
                    Text("Rep \(repNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if let depth = analysis.metrics["deepest_angle"],
                       let duration = analysis.metrics["rep_duration"] {
                        Text("Depth: \(Int(depth))° • Duration: \(String(format: "%.1f", duration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(analysis.score * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.score > 0.7 ? .green : analysis.score > 0.5 ? .orange : .red)
                    
                    Text(scoreDescription(for: analysis.score))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Feedback
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(analysis.feedback.prefix(4), id: \.self) { feedback in
                    Text(feedback)
                        .font(.caption)
                        .padding(8)
                        .background(feedbackColor(for: feedback).opacity(0.1))
                        .cornerRadius(8)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func scoreDescription(for score: Float) -> String {
        switch score {
        case 0.9...: return "Excellent"
        case 0.75..<0.9: return "Great"
        case 0.6..<0.75: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Needs Work"
        }
    }
    
    private func feedbackColor(for feedback: String) -> Color {
        if feedback.contains("🏆") || feedback.contains("✅") || feedback.contains("💪") {
            return .green
        } else if feedback.contains("⚠️") || feedback.contains("🔽") {
            return .orange
        } else if feedback.contains("🎯") || feedback.contains("📐") {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - Video Transfer
struct VideoFile: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "imported_video.mov")
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
} 