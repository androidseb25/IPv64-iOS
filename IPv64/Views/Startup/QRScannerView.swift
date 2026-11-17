//
//  QRScannerView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//


import SwiftUI
import AVFoundation
import Combine

// MARK: - Public SwiftUI View

/// Vollbild QR-Code Scanner, mit zentraler "Frosted-Glass"-Kachel und rotem Rahmen wie im Screenshot.
/// Usage:
/// QRScannerView { payload in
///     print("Scanned:", payload)
/// }

public struct QRScannerView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var scanner = QRScanner()
    
    public var onScanned: (String) -> Void
    
    public init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }
    
    public var body: some View {
        ZStack {
            CameraPreview(session: scanner.session)
                .ignoresSafeArea()
            
            // The cutout is only a visual guide: the whole camera frame is scanned (no rectOfInterest, which
            // silently stopped all detection when converted before the preview had its size or rotation).
            GeometryReader { geo in
                ScannerCutoutOverlay(side: min(geo.size.width, geo.size.height) * 0.62)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
        }
        .task {
            await scanner.start { code in
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onScanned(code)
                Task {
                    await scanner.stop()
                    dismiss()
                } // async separat
            }
        }
        .onDisappear {
            Task { await scanner.stop() }
        }
    }
}

private struct ScannerCutoutOverlay: View {
    let side: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            let cutout = CGRect(x: cx - side/2, y: cy - side/2, width: side, height: side)
            let corner = side * 0.10
            
            // Frosted Außenbereich (even-odd)
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addPath(RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: cutout))
            }
            .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            
            // Roter Rahmen um das Scan-Fenster
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.red, lineWidth: max(2, side * 0.012))
                .frame(width: cutout.width, height: cutout.height)
                .position(x: cx, y: cy)
                .shadow(radius: side * 0.04, y: side * 0.02)
        }
    }
}

// MARK: - Camera Preview (AVCaptureVideoPreviewLayer in SwiftUI)

private struct CameraPreview: UIViewRepresentable {
    final class VideoView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        private var coordinator: AVCaptureDevice.RotationCoordinator?
        private var observation: NSKeyValueObservation?

        /// Keeps the preview upright in every orientation and window size (iPad landscape, Split View).
        func followRotation() {
            guard coordinator == nil,
                  let device = (previewLayer.session?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            self.coordinator = coordinator
            apply(coordinator.videoRotationAngleForHorizonLevelPreview)
            observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                let view = self
                Task { @MainActor in view?.apply(angle) }
            }
        }

        private func apply(_ angle: CGFloat) {
            guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoView {
        let v = VideoView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        v.followRotation()
        return v
    }
    
    func updateUIView(_ uiView: VideoView, context: Context) {
        uiView.followRotation() // the camera input may be added after the view was made
    }
}

// MARK: - Scanner Core
final class QRScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "qr.scanner.session") // ⬅️ neu
    
    private var onCode: ((String) -> Void)?
    private var isRunning = false
    
    private let metadataOutput = AVCaptureMetadataOutput()
    
    // MARK: Public API
    
    func start(onCode: @escaping (String) -> Void) async {
        self.onCode = onCode
        if isRunning { return }
        
        await withCheckedContinuation { cont in
            sessionQueue.async {
                self.configureSessionIfNeeded()     // ⬅️ auf der Queue
                self.session.startRunning()         // ⬅️ auf der Queue
                self.isRunning = true
                cont.resume()
            }
        }
    }
    
    func stop() async {
        guard isRunning else { return }
        await withCheckedContinuation { cont in
            sessionQueue.async {
                self.session.stopRunning()          // ⬅️ auf der Queue
                self.isRunning = false
                cont.resume()
            }
        }
    }
    
    // MARK: Session Setup
    
    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty && session.outputs.isEmpty else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        // Keep scanning while other apps share the screen (Split View, Slide Over, Stage Manager).
        if session.isMultitaskingCameraAccessSupported { session.isMultitaskingCameraAccessEnabled = true }
        
        // Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        
        // Output
        guard session.canAddOutput(metadataOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
        }
        
        session.commitConfiguration()
        
        // Autofokus
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()
    }

    // MARK: Delegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue,
              !value.isEmpty else { return }
        onCode?(value)
        onCode = nil
    }
}

#Preview {
    QRScannerView() { _ in }
}
