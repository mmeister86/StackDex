import AVFoundation
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    enum CaptureError: Error {
        case busy
        case imageDataMissing
        case captureFailed
    }

    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "stackdex.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureHandler: ((Result<UIImage, Error>) -> Void)?

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
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
            settings.photoQualityPrioritization = .balanced
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

            guard self.session.canAddOutput(self.photoOutput) else {
                return
            }

            self.session.addOutput(self.photoOutput)
            self.photoOutput.maxPhotoQualityPrioritization = .quality
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
