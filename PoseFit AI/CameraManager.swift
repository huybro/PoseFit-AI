import AVFoundation
import SwiftUI
import Vision

class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    
    // Add these for pose detection
    private var poseRequest: VNDetectHumanBodyPose3DRequest?
    @Published var detectedPoses: [VNHumanBodyPose3DObservation] = []
    @Published var currentAnalysis: WorkoutAnalysis? = nil
    @Published var stableFeedback: WorkoutAnalysis? = nil
    
    var currentWorkoutType: WorkoutType = .squat
    
    private var lastProcessTime = Date()
    private let processingInterval: TimeInterval = 0.1 // Process every 100ms (10 FPS)
    
    private var feedbackTimer: Timer?
    private let feedbackDisplayDuration: TimeInterval = 3.0
    
    var session: AVCaptureSession {
        return captureSession
    }
    
    override init() {
        super.init()
        setupPoseDetection()
    }
    
    func setupCamera() {
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                       for: .video, 
                                                       position: .front),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(videoDeviceInput)
        
        // 2. Setup video output (for getting frames later)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("❌ Failed to add video output")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(videoOutput)
        print("✅ Video output added")
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        print("▶️ Starting camera session...")
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPose3DRequest { [weak self] request, error in
            guard let results = request.results as? [VNHumanBodyPose3DObservation],
                  let firstPose = results.first else { 
                print("❌ No 3D poses detected")
                return 
            }
            
            DispatchQueue.main.async {
                self?.detectedPoses = results
                print("🎯 Detected 3D pose with \(firstPose.availableJointNames.count) joints")
                self?.analyzeCurrentPose3D(firstPose)
            }
        }
    }
    
    private func analyzeCurrentPose(_ pose: VNHumanBodyPoseObservation) {
        let analysis: WorkoutAnalysis?
        
        switch currentWorkoutType {
        case .squat:
            analysis = PoseAnalyzer.analyzeSquat(pose: pose)
        case .pushUp:
            analysis = nil
        case .plank:
            analysis = nil
        }
        
        if let newAnalysis = analysis {
            currentAnalysis = newAnalysis
            
            // Update stable feedback and reset timer
            stableFeedback = newAnalysis
            resetFeedbackTimer()
        }
    }
    
    private func analyzeCurrentPose3D(_ pose: VNHumanBodyPose3DObservation) {
        let analysis: WorkoutAnalysis?
        
        switch currentWorkoutType {
        case .squat:
            analysis = PoseAnalyzer.analyzeSquat3D(pose: pose)
        case .pushUp:
            analysis = nil
        case .plank:
            analysis = nil
        }
        
        if let newAnalysis = analysis {
            currentAnalysis = newAnalysis
            
            // Update stable feedback and reset timer
            stableFeedback = newAnalysis
            resetFeedbackTimer()
        }
    }
    
    private func resetFeedbackTimer() {
        feedbackTimer?.invalidate()
        
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: feedbackDisplayDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                // Only clear feedback if no new analysis came in
                if let lastAnalysis = self?.currentAnalysis,
                   Date().timeIntervalSince(lastAnalysis.timestamp) > self?.feedbackDisplayDuration ?? 0 {
                    self?.stableFeedback = nil
                }
            }
        }
    }
    
    deinit {
        feedbackTimer?.invalidate()
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.videoPreviewLayer.session = cameraManager.session
        previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        return previewView
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // No need to update frame - the layer handles it automatically
    }
}

// MARK: - PreviewView (Apple's Pattern)
class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}


// MARK: - Video Frame Capture
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Get the pixel buffer from the frame
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let poseRequest = poseRequest else { return }
        
        // Process pose detection on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            
            do {
                try handler.perform([poseRequest])
            } catch {
                print("❌ Pose detection error: \(error)")
            }
        }
    }
}
