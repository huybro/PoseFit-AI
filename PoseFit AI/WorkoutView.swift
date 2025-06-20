import SwiftUI

struct WorkoutView: View {
    @Binding var isPresented: Bool
    let workoutType: WorkoutType
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
                .onAppear {
                    cameraManager.currentWorkoutType = workoutType
                    cameraManager.setupCamera()
                    cameraManager.startSession()
                }
                .onDisappear {
                    cameraManager.stopSession()
                }
            
            // Pose Overlay
            GeometryReader { geometry in
                PoseOverlayView(poses: cameraManager.detectedPoses, frameSize: geometry.size)
            }
            
            VStack {
                // Top section with Exit button
                HStack {
                    Button("Exit") {
                        isPresented = false
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Show selected workout type
                    Text(workoutType.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
                
                // Add feedback display
                if let analysis = cameraManager.currentAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Form Score: \(Int(analysis.score * 100))%")
                                .fontWeight(.bold)
                                .foregroundColor(analysis.score > 0.7 ? .green : .orange)
                            
                            Spacer()
                        }
                        
                        ForEach(analysis.feedback, id: \.self) { feedback in
                            Text(feedback)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
}

