import AVFoundation
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    struct FocusIndicatorState: Equatable {
        enum Phase: Equatable {
            case idle
            case active
        }

        let phase: Phase
        let previewPoint: CGPoint?

        static let idle = FocusIndicatorState(phase: .idle, previewPoint: nil)
    }

    enum SessionInterruptionState: Equatable {
        case none
        case interrupted(message: String)
    }

    enum CaptureError: Error {
        case busy
        case imageDataMissing
        case captureFailed
    }

    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var focusIndicatorState: FocusIndicatorState = .idle
    @Published private(set) var interruptionState: SessionInterruptionState = .none
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "stackdex.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureHandler: ((Result<UIImage, Error>) -> Void)?
    private var activeDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var captureRotationAngle: CGFloat = 0
    private var interruptionObservers: [NSObjectProtocol] = []
    private var focusResetTask: Task<Void, Never>?

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()

        if ProcessInfo.processInfo.arguments.contains("-uitest-scanner-interrupted") {
            interruptionState = .interrupted(message: "Kamera voruebergehend nicht verfuegbar. Nach der Unterbrechung erneut versuchen.")
        }
    }

    deinit {
        interruptionObservers.forEach(NotificationCenter.default.removeObserver)
        focusResetTask?.cancel()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccessIfNeeded() async -> Bool {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        if current == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
        } else {
            authorizationStatus = current
        }

        return authorizationStatus == .authorized
    }

    func startSessionIfAuthorized() {
        guard authorizationStatus == .authorized else { return }
        configureIfNeeded()

        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func attachPreviewLayer(_ previewLayer: AVCaptureVideoPreviewLayer) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.previewLayer = previewLayer
            self.configureRotationCoordinatorIfPossible()
        }
    }

    func detachPreviewLayer() {
        sessionQueue.async { [weak self] in
            self?.rotationObservation = nil
            self?.rotationCoordinator = nil
            self?.previewLayer = nil
        }
    }

    func focusAndExpose(atPreviewPoint previewPoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard
                let self,
                let previewLayer = self.previewLayer,
                let device = self.activeDevice
            else {
                return
            }

            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: previewPoint)

            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }

                device.isSubjectAreaChangeMonitoringEnabled = true
            } catch {
                return
            }

            self.publishFocusIndicator(at: previewPoint)
        }
    }

    func capturePhoto(_ completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CaptureError.captureFailed))
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.captureHandler != nil {
                DispatchQueue.main.async {
                    completion(.failure(CaptureError.busy))
                }
                return
            }

            self.captureHandler = completion
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            if #available(iOS 17.0, *),
               let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(self.captureRotationAngle) {
                connection.videoRotationAngle = self.captureRotationAngle
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.sessionPreset = .photo

            guard
                let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: camera),
                self.session.canAddInput(input)
            else {
                return
            }

            self.session.addInput(input)
            self.activeDevice = camera

            guard self.session.canAddOutput(self.photoOutput) else {
                return
            }

            self.session.addOutput(self.photoOutput)
            self.photoOutput.maxPhotoQualityPrioritization = .quality
            self.configureDefaultScannerFocusAndExposure(for: camera)
            self.configureRotationCoordinatorIfPossible()
            self.registerInterruptionObserversIfNeeded()
        }
    }

    private func configureDefaultScannerFocusAndExposure(for device: AVCaptureDevice) {
        let defaultPoint = CGPoint(x: 0.5, y: 0.5)

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported,
               device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = defaultPoint
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = defaultPoint
                device.exposureMode = .continuousAutoExposure
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            return
        }
    }

    private func registerInterruptionObserversIfNeeded() {
        guard interruptionObservers.isEmpty else { return }

        let notificationCenter = NotificationCenter.default

        interruptionObservers.append(
            notificationCenter.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleSessionInterruption(notification)
            }
        )

        interruptionObservers.append(
            notificationCenter.addObserver(
                forName: .AVCaptureSessionInterruptionEnded,
                object: session,
                queue: .main
            ) { [weak self] _ in
                self?.interruptionState = .none
            }
        )
    }

    private func handleSessionInterruption(_ notification: Notification) {
        guard !ProcessInfo.processInfo.arguments.contains("-uitest-scanner-interrupted") else {
            return
        }

        let rawReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber
        let reason = rawReason.flatMap { AVCaptureSession.InterruptionReason(rawValue: $0.intValue) }
        interruptionState = .interrupted(message: interruptionMessage(for: reason))
    }

    private func interruptionMessage(for reason: AVCaptureSession.InterruptionReason?) -> String {
        switch reason {
        case .videoDeviceInUseByAnotherClient:
            return "Kamera wird gerade von einer anderen App verwendet. Danach erneut versuchen."
        case .videoDeviceNotAvailableInBackground:
            return "Scanner pausiert im Hintergrund und ist beim Zurueckkehren wieder bereit."
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            return "Kamera ist in dieser Multiwindow-Ansicht nicht verfuegbar."
        case .audioDeviceInUseByAnotherClient:
            return "Audio-Hardware ist belegt. Scanner bleibt pausiert, bis sie wieder frei ist."
        case .sensitiveContentMitigationActivated:
            return "Kamera ist wegen Inhaltsschutz gerade eingeschraenkt. Bitte kurz warten."
        case .videoDeviceNotAvailableDueToSystemPressure:
            return "Kamera ist wegen Systemauslastung kurz nicht verfuegbar. Bitte einen Moment warten."
        case .none:
            return "Kamera voruebergehend nicht verfuegbar. Nach der Unterbrechung erneut versuchen."
        @unknown default:
            return "Kamera wurde unterbrochen. Bitte gleich erneut versuchen."
        }
    }

    nonisolated private func publishFocusIndicator(at previewPoint: CGPoint) {
        Task { @MainActor in
            focusResetTask?.cancel()
            focusIndicatorState = .init(phase: .active, previewPoint: previewPoint)
            focusResetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                focusIndicatorState = .idle
            }
        }
    }

    private func configureRotationCoordinatorIfPossible() {
        guard #available(iOS 17.0, *) else {
            return
        }
        guard let activeDevice, let previewLayer else {
            return
        }

        rotationObservation = nil
        let coordinator = AVCaptureDevice.RotationCoordinator(device: activeDevice, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        captureRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture

        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self, weak previewLayer] coordinator, _ in
            guard let self, let previewLayer else { return }
            let previewAngle = coordinator.videoRotationAngleForHorizonLevelPreview
            let captureAngle = coordinator.videoRotationAngleForHorizonLevelCapture

            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(previewAngle) {
                connection.videoRotationAngle = previewAngle
            }
            self.captureRotationAngle = captureAngle
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            finishCapture(with: .failure(error))
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            finishCapture(with: .failure(CaptureError.imageDataMissing))
            return
        }

        finishCapture(with: .success(image))
    }

    nonisolated private func finishCapture(with result: Result<UIImage, Error>) {
        Task { @MainActor in
            let handler = captureHandler
            captureHandler = nil
            handler?(result)
        }
    }
}
#endif
