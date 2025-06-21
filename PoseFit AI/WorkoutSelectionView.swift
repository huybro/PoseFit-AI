import SwiftUI

struct WorkoutSelectionView: View {
    @Binding var isPresented: Bool
    @State private var selectedWorkout: WorkoutType? = nil
    @State private var showVideoUploadView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Your Workout")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Workout Options
                VStack(spacing: 16) {
                    WorkoutCard(
                        workout: .squat,
                        isSelected: selectedWorkout == .squat
                    ) {
                        selectedWorkout = .squat
                    }
                    
                    WorkoutCard(
                        workout: .pushUp,
                        isSelected: selectedWorkout == .pushUp
                    ) {
                        selectedWorkout = .pushUp
                    }
                    
                    WorkoutCard(
                        workout: .plank,
                        isSelected: selectedWorkout == .plank
                    ) {
                        selectedWorkout = .plank
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Start Button
                if let workout = selectedWorkout {
                    Button("Analyze \(workout.displayName)") {
                        showVideoUploadView = true
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showVideoUploadView) {
            if let workout = selectedWorkout {
                VideoUploadView(isPresented: $showVideoUploadView, workoutType: workout)
            }
        }
    }
}

// MARK: - Workout Types
enum WorkoutType: String, CaseIterable {
    case squat = "squat"
    case pushUp = "pushup"  
    case plank = "plank"
    
    var displayName: String {
        switch self {
        case .squat: return "Squats"
        case .pushUp: return "Push-ups"
        case .plank: return "Plank"
        }
    }
    
    var icon: String {
        switch self {
        case .squat: return "figure.squat"
        case .pushUp: return "figure.core.training"
        case .plank: return "figure.flexibility"
        }
    }
    
    var description: String {
        switch self {
        case .squat: return "Lower body strength"
        case .pushUp: return "Upper body strength"
        case .plank: return "Core stability"
        }
    }
}

// MARK: - Workout Card
struct WorkoutCard: View {
    let workout: WorkoutType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: workout.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(workout.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}
