//
//  ContentView.swift
//  PoseFit AI
//
//  Created by Cao Gia Huy on 6/20/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showWorkoutSelection = false

    var body: some View {
        VStack(spacing: 40) {
            // App Name Section
            VStack(spacing: 16) {
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("PoseFit AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("AI-Powered Workout Form Trainer")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            
            // Main CTA Button
            Button(action: {
                showWorkoutSelection = true
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.cyan]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .fullScreenCover(isPresented: $showWorkoutSelection) {
            WorkoutSelectionView(isPresented: $showWorkoutSelection)
        }
    }
}

#Preview {
    ContentView()
}
