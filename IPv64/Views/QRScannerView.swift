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
            CameraPreview(session: scanner.session) { layer in
                // PreviewLayer an den Scanner durchreichen (für rectOfInterest-Konvertierung)
                scanner.attach(previewLayer: layer)
            }
            .ignoresSafeArea()
            
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.62
                ScannerCutoutOverlay(side: side) { cutout in
                    // Bei Layout-Änderungen das Interesse-Rechteck updaten
                    scanner.updateRectOfInterest(fromLayerRect: cutout)
                }
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
    var onCutoutChanged: (CGRect) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            let cutout = CGRect(x: cx - side/2, y: cy - side/2, width: side, height: side)
            let corner = side * 0.10
            
            // notify scanner about new cutout each layout pass
            Color.clear
                .onAppear { onCutoutChanged(cutout) }
                .onChange(of: geo.size) { _, _ in onCutoutChanged(cutout) }
            
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
    }
    
    let session: AVCaptureSession
    var onLayerAvailable: (AVCaptureVideoPreviewLayer) -> Void
    
    func makeUIView(context: Context) -> VideoView {
        let v = VideoView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = v.previewLayer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90 // Hochformat
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        onLayerAvailable(v.previewLayer)
        return v
    }
    
    func updateUIView(_ uiView: VideoView, context: Context) {
        if let connection = uiView.previewLayer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        onLayerAvailable(uiView.previewLayer)
    }
}

// MARK: - Scanner Core
final class QRScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "qr.scanner.session") // ⬅️ neu
    
    private var onCode: ((String) -> Void)?
    private var isRunning = false
    
    // Für rectOfInterest
    private let metadataOutput = AVCaptureMetadataOutput()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var pendingLayerRectForROI: CGRect?
    
    func attach(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        // Falls bereits ein Cutout bekannt ist, setze ROI jetzt
        if let cutout = pendingLayerRectForROI {
            setRectOfInterest(layerRect: cutout)
        }
    }
    
    func updateRectOfInterest(fromLayerRect layerRect: CGRect) {
        // Wenn PreviewLayer schon da ist: direkt setzen, sonst merken
        guard let layer = previewLayer else {
            pendingLayerRectForROI = layerRect
            return
        }
        // Normierung im Layer-Koordinatensystem — Layer gehört zur Main-Thread-Welt
        let normalized = layer.metadataOutputRectConverted(fromLayerRect: layerRect)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.outputs.contains(self.metadataOutput) {
                self.metadataOutput.rectOfInterest = normalized
            } else {
                self.pendingLayerRectForROI = layerRect
            }
        }
    }
    
    private func setRectOfInterest(layerRect: CGRect) {
        guard let layer = previewLayer else { return }
        let normalized = layer.metadataOutputRectConverted(fromLayerRect: layerRect)
        // Nur setzen, wenn Session schon konfiguriert ist
        if session.outputs.contains(metadataOutput) {
            metadataOutput.rectOfInterest = normalized
        }
        pendingLayerRectForROI = nil
    }
    
    // MARK: Public API
    
    func start(onCode: @escaping (String) -> Void) async {
        self.onCode = onCode
        if isRunning { return }
        
        await withCheckedContinuation { cont in
            sessionQueue.async {
                self.configureSessionIfNeeded()     // ⬅️ auf der Queue
                self.session.startRunning()         // ⬅️ auf der Queue
                self.isRunning = true
                
                // Falls Cutout schon da war, ROI setzen
                if let cut = self.pendingLayerRectForROI, self.previewLayer != nil {
                    self._setRectOfInterestOnSessionQueue(layerRect: cut)
                }
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

    // Fallback falls wir schon auf sessionQueue sind
    private func _setRectOfInterestOnSessionQueue(layerRect: CGRect) {
        guard let layer = previewLayer else { return }
        // Konvertierung muss über den Layer passieren → zurück auf Main, dann wieder setzen
        DispatchQueue.main.async {
            let normalized = layer.metadataOutputRectConverted(fromLayerRect: layerRect)
            self.sessionQueue.async {
                if self.session.outputs.contains(self.metadataOutput) {
                    self.metadataOutput.rectOfInterest = normalized
                }
                self.pendingLayerRectForROI = nil
            }
        }
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
    QRScannerView() { key in
        print(key)
    }
}
