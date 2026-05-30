//
//  CameraController.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import Foundation
import AVFoundation
import UIKit

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "pika.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var position: AVCaptureDevice.Position = .front
    private var captureDelegate: PhotoCaptureDelegate?
    private var isConfigured = false

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let isAuthorized: Bool

        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }

        guard isAuthorized else {
            DispatchQueue.main.async {
                self.errorMessage = "Camera access is needed to take your onboarding photo."
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if self.isConfigured, !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func flipCamera() {
        position = position == .front ? .back : .front
        isConfigured = false

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
        }
    }

    func capturePhoto(_ completion: @escaping (Data) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.errorMessage == nil else { return }

            let settings = AVCapturePhotoSettings()
            let delegate = PhotoCaptureDelegate { [weak self] data in
                DispatchQueue.main.async {
                    self?.captureDelegate = nil
                    if let data {
                        completion(data)
                    } else {
                        self?.errorMessage = "Could not capture your photo. Please try again."
                    }
                }
            }

            self.captureDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.errorMessage = "Camera is unavailable on this device."
            }
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        isConfigured = true

        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            completion(nil)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let encodedData = image.jpegData(compressionQuality: 0.9) else {
            completion(nil)
            return
        }

        completion(encodedData)
    }
}
