import SwiftUI
@preconcurrency import AVFoundation

/// Full-screen QR scanner (back camera, QR only). The first decoded text is delivered once, verbatim.
/// Cancel keeps the API key field unchanged (deviation: Android clears it).
struct QRScannerView: View {
    let onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var camera = QRCamera()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            ScannerCutout().ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            Button("Cancel", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.title3)
                .appGlassButtonStyle()
                .buttonBorderShape(.circle)
                .padding(16)
        }
        .task {
            for await code in camera.codes() {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onScanned(code)
                dismiss()
                break
            }
        }
    }
}

/// Owns the capture session; configuration and start/stop run on this actor, off the main thread.
private actor QRCameraSessionRunner {
    func start(_ session: AVCaptureSession, delegate: QRCodeDelegate) {
        if session.inputs.isEmpty {
            session.beginConfiguration()
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    output.setMetadataObjectsDelegate(delegate, queue: .main)
                    if output.availableMetadataObjectTypes.contains(.qr) { output.metadataObjectTypes = [.qr] }
                }
            }
            session.commitConfiguration()
        }
        session.startRunning()
    }

    func stop(_ session: AVCaptureSession) { session.stopRunning() }
}

/// Main-queue metadata delegate that forwards QR payloads into an AsyncStream.
private final class QRCodeDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate, Sendable {
    let stream: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    override init() {
        (stream, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr, let value = object.stringValue, !value.isEmpty else { return }
        continuation.yield(value)
    }

    nonisolated func finish() { continuation.finish() }
}

@Observable
private final class QRCamera {
    // AVCaptureSession is documented as safe to start/stop from a background queue while the preview layer
    // (main thread) references it; all mutations happen inside QRCameraSessionRunner.
    nonisolated(unsafe) let session = AVCaptureSession()
    private let runner = QRCameraSessionRunner()

    /// Starts the camera and yields scanned codes until the consumer stops iterating.
    func codes() -> AsyncStream<String> {
        let delegate = QRCodeDelegate()
        let session = session
        let runner = runner
        Task { await runner.start(session, delegate: delegate) }
        return AsyncStream { continuation in
            let forward = Task {
                for await code in delegate.stream { continuation.yield(code) }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                forward.cancel()
                delegate.finish()
                Task { await runner.stop(session) }
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

/// Frosted surround with a red frame around the scan window.
private struct ScannerCutout: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            let rect = CGRect(x: (geo.size.width - side) / 2, y: (geo.size.height - side) / 2, width: side, height: side)
            let corner = side * 0.10
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addPath(RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect))
            }
            .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.red, lineWidth: max(2, side * 0.012))
                .frame(width: side, height: side)
                .position(x: rect.midX, y: rect.midY)
        }
    }
}
