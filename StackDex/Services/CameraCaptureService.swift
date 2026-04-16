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

    struct ZoomState: Equatable {
        let current: CGFloat
        let min: CGFloat
        let max: CGFloat
        let steps: [CGFloat]
        let isAvailable: Bool

        static let unavailable = ZoomState(
            current: 1,
            min: 1,
            max: 1,
            steps: [1],
            isAvailable: false
        )
    }

    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var focusIndicatorState: FocusIndicatorState = .idle
    @Published private(set) var interruptionState: SessionInterruptionState = .none
    @Published private(set) var zoomState: ZoomState = .unavailable
    @Published private(set) var isSessionRunning = false
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
    private var subjectAreaDidChangeObserver: NSObjectProtocol?
    private var autoFocusRecenterWorkItem: DispatchWorkItem?
    private var focusResetTask: Task<Void, Never>?
    private var zoomRange: ClosedRange<CGFloat> = 1 ... 1
    private var zoomSteps: [CGFloat] = [1]
    private var pinchBaseZoomFactor: CGFloat?

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()

        if ProcessInfo.processInfo.arguments.contains("-uitest-scanner-interrupted") {
            interruptionState = .interrupted(message: "Kamera voruebergehend nicht verfuegbar. Nach der Unterbrechung erneut versuchen.")
        }
    }

    deinit {
        interruptionObservers.forEach(NotificationCenter.default.removeObserver)
        if let subjectAreaDidChangeObserver {
            NotificationCenter.default.removeObserver(subjectAreaDidChangeObserver)
        }
        autoFocusRecenterWorkItem?.cancel()
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
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
            }
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

                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                } else if device.isFocusPointOfInterestSupported,
                          device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .continuousAutoFocus
                }

                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                } else if device.isExposurePointOfInterestSupported,
                          device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            } catch {
                return
            }

            self.scheduleAutoFocusRecentering()
            self.publishFocusIndicator(at: previewPoint)
        }
    }

    func setZoomFactor(_ factor: CGFloat, animated: Bool) {
        guard authorizationStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else { return }

            let clamped = min(max(factor, self.zoomRange.lowerBound), self.zoomRange.upperBound)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if animated {
                    let rate: Float = clamped >= device.videoZoomFactor ? 8 : 10
                    device.ramp(toVideoZoomFactor: clamped, withRate: rate)
                } else {
                    if device.isRampingVideoZoom {
                        device.cancelVideoZoomRamp()
                    }
                    device.videoZoomFactor = clamped
                }
            } catch {
                return
            }

            self.publishZoomState(
                current: clamped,
                min: self.zoomRange.lowerBound,
                max: self.zoomRange.upperBound,
                steps: self.zoomSteps
            )
        }
    }

    func beginPinchZoom() {
        guard authorizationStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else { return }
            self.pinchBaseZoomFactor = device.videoZoomFactor
        }
    }

    func updatePinchZoom(scale: CGFloat) {
        guard authorizationStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard
                let self,
                let device = self.activeDevice,
                let base = self.pinchBaseZoomFactor
            else {
                return
            }

            let target = min(max(base * scale, self.zoomRange.lowerBound), self.zoomRange.upperBound)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = target
            } catch {
                return
            }

            self.publishZoomState(
                current: target,
                min: self.zoomRange.lowerBound,
                max: self.zoomRange.upperBound,
                steps: self.zoomSteps
            )
        }
    }

    func endPinchZoom() {
        sessionQueue.async { [weak self] in
            self?.pinchBaseZoomFactor = nil
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
                let camera = Self.preferredBackCameraDevice(),
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
            self.configureZoom(for: camera)
            self.registerSubjectAreaChangeObserver(for: camera)
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
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }

            if device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = defaultPoint
                device.exposureMode = .continuousAutoExposure
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            device.isSubjectAreaChangeMonitoringEnabled = true
        } catch {
            return
        }
    }

    private func registerSubjectAreaChangeObserver(for device: AVCaptureDevice) {
        if let subjectAreaDidChangeObserver {
            NotificationCenter.default.removeObserver(subjectAreaDidChangeObserver)
        }

        subjectAreaDidChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: device,
            queue: nil
        ) { [weak self] _ in
            self?.sessionQueue.async { [weak self] in
                self?.recenterFocusAndExposureIfPossible()
            }
        }
    }

    private func scheduleAutoFocusRecentering() {
        autoFocusRecenterWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.recenterFocusAndExposureIfPossible()
        }
        autoFocusRecenterWorkItem = workItem
        sessionQueue.asyncAfter(deadline: .now() + 1.1, execute: workItem)
    }

    private func recenterFocusAndExposureIfPossible() {
        guard let activeDevice else { return }
        configureDefaultScannerFocusAndExposure(for: activeDevice)
    }

    private static func preferredBackCameraDevice() -> AVCaptureDevice? {
        if let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return triple
        }
        if let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return dualWide
        }
        if let dual = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return dual
        }
        if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return wide
        }
        return nil
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
                self?.isSessionRunning = self?.session.isRunning ?? false
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

    private func configureZoom(for device: AVCaptureDevice) {
        let configuration = CameraZoomConfigurationBuilder.make(
            minAvailable: device.minAvailableVideoZoomFactor,
            maxAvailable: device.maxAvailableVideoZoomFactor,
            switchOverFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        )

        zoomRange = configuration.min ... configuration.max
        zoomSteps = configuration.steps
        pinchBaseZoomFactor = nil

        var currentZoomFactor = configuration.defaultZoom
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isRampingVideoZoom {
                device.cancelVideoZoomRamp()
            }
            device.videoZoomFactor = configuration.defaultZoom
            currentZoomFactor = device.videoZoomFactor
        } catch {
            currentZoomFactor = min(max(device.videoZoomFactor, configuration.min), configuration.max)
        }

        publishZoomState(
            current: currentZoomFactor,
            min: configuration.min,
            max: configuration.max,
            steps: configuration.steps
        )
    }

    nonisolated private func publishZoomState(current: CGFloat, min: CGFloat, max: CGFloat, steps: [CGFloat]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.zoomState = ZoomState(
                current: current,
                min: min,
                max: max,
                steps: steps,
                isAvailable: steps.count > 1 || (max - min) > 0.05
            )
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

struct CameraZoomConfiguration: Equatable {
    let min: CGFloat
    let max: CGFloat
    let steps: [CGFloat]
    let defaultZoom: CGFloat
}

enum CameraZoomConfigurationBuilder {
    static let maxScannerZoomFactor: CGFloat = 3

    static func make(
        minAvailable: CGFloat,
        maxAvailable: CGFloat,
        switchOverFactors: [CGFloat]
    ) -> CameraZoomConfiguration {
        let safeMin = max(1, minAvailable.isFinite ? minAvailable : 1)
        let clampedMaxInput = max(maxAvailable.isFinite ? maxAvailable : safeMin, safeMin)
        let safeMax = max(safeMin, min(maxScannerZoomFactor, clampedMaxInput))

        var candidates = [CGFloat](arrayLiteral: 1, 2, 3)
        candidates.append(contentsOf: switchOverFactors)

        let sorted = candidates
            .filter { $0.isFinite && $0 > 0 }
            .map { min(max($0, safeMin), safeMax) }
            .sorted()

        var deduplicated: [CGFloat] = []
        for value in sorted {
            if let last = deduplicated.last, abs(last - value) < 0.01 {
                continue
            }
            deduplicated.append(value)
        }

        if deduplicated.isEmpty {
            deduplicated = [safeMin]
        }

        let defaultZoom = min(max(1, safeMin), safeMax)
        return CameraZoomConfiguration(
            min: safeMin,
            max: safeMax,
            steps: deduplicated,
            defaultZoom: defaultZoom
        )
    }
}
#endif
