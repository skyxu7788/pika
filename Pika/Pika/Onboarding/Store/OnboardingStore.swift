//
//  OnboardingStore.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import Foundation
import CoreData
import AVFoundation

@MainActor
final class OnboardingStore: ObservableObject, Identifiable {
    let id = UUID()
    let user: User

    @Published var currentStep: OnboardingStep
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    private let repository: UserRepository
    private let audioRecorder = AudioRecorder()
    private var reachedCompleteInSession = false

    init(user: User, context: NSManagedObjectContext, initialStep: OnboardingStep) {
        self.user = user
        self.currentStep = initialStep
        self.repository = UserRepository(context: context)
    }

    func goBack() -> Bool {
        switch currentStep {
        case .photo:
            return false
        case .voice:
            currentStep = .photo
            return true
        case .complete:
            guard reachedCompleteInSession else { return false }
            currentStep = .voice
            return true
        }
    }

    func savePhoto(_ data: Data) {
        do {
            try repository.savePhoto(data, for: user)
            currentStep = .voice
            errorMessage = nil
        } catch {
            errorMessage = "Could not save your photo. Please try again."
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func stopRecordingIfNeeded() {
        if isRecording {
            stopRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                transcript = ""
                try await audioRecorder.start(
                    onTranscript: { [weak self] transcript in
                        Task { @MainActor in
                            self?.transcript = transcript
                        }
                    },
                    onError: { [weak self] error in
                        Task { @MainActor in
                            self?.errorMessage = "Speech recognition is not available right now."
                            print("speech recognition error: \(error)")
                        }
                    }
                )
                isRecording = true
                errorMessage = nil
            } catch {
                errorMessage = "Could not start recording. Check microphone and speech access."
            }
        }
    }

    private func stopRecording() {
        do {
          // change it so it only saves to user and proceed to next if it transcript mached with all the paragrah. if you press stop before it matched with all, show an alert telling you have to say all words to proceed and give an option to retry?
            let data = try audioRecorder.stop()
            try repository.saveAudio(data, for: user)
            isRecording = false
            reachedCompleteInSession = true
            currentStep = .complete
            errorMessage = nil
        } catch {
            isRecording = false
            errorMessage = "Could not save your recording. Please try again."
        }
    }
}
