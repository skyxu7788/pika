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
    @Published var isVoiceReadyForReview = false
    @Published var isPlayingRecordedAudio = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    private let repository: UserRepository
    private let audioRecorder = AudioRecorder()
    private var audioPlayer: AVAudioPlayer?
    private var pendingAudioData: Data?
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
            errorMessage = "Read the full paragraph before continuing."
        } else {
            startRecording()
        }
    }

    func stopRecordingIfNeeded() {
        if isRecording {
            discardCurrentRecording()
        }
        stopPlayback()
    }

    func retryVoiceRecording() {
        discardCurrentRecording()
        startRecording()
    }

    func playRecordedAudio() {
        guard let pendingAudioData else {
            errorMessage = "Record the paragraph before playback."
            return
        }

        do {
            stopPlayback()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(data: pendingAudioData)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            isPlayingRecordedAudio = true
            errorMessage = nil
        } catch {
            errorMessage = "Could not play your recording."
        }
    }

    func confirmVoiceRecording() {
        guard isVoiceReadyForReview, let pendingAudioData else {
            errorMessage = "Read the full paragraph before continuing."
            return
        }

        do {
            stopPlayback()
            try repository.saveAudio(pendingAudioData, for: user)
            reachedCompleteInSession = true
            currentStep = .complete
            errorMessage = nil
        } catch {
            errorMessage = "Could not save your recording. Please try again."
        }
    }

    private func startRecording() {
        Task {
            do {
                stopPlayback()
                pendingAudioData = nil
                isVoiceReadyForReview = false
                isPlayingRecordedAudio = false
                transcript = ""
                try await audioRecorder.start(
                    onTranscript: { [weak self] transcript in
                        Task { @MainActor in
                            self?.handleTranscript(transcript)
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

    private func handleTranscript(_ transcript: String) {
        self.transcript = transcript

        guard isRecording, hasMatchedPrompt(transcript) else { return }
        finishRecordingForReview()
    }

    private func finishRecordingForReview() {
        do {
            let data = try audioRecorder.stop()
            pendingAudioData = data
            isRecording = false
            isVoiceReadyForReview = true
            errorMessage = nil
        } catch {
            isRecording = false
            errorMessage = "Could not finish your recording. Please try again."
        }
    }

    private func discardCurrentRecording() {
        if isRecording {
            _ = try? audioRecorder.stop()
        }

        stopPlayback()
        pendingAudioData = nil
        isRecording = false
        isVoiceReadyForReview = false
        isPlayingRecordedAudio = false
        transcript = ""
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingRecordedAudio = false
    }

    private func hasMatchedPrompt(_ transcript: String) -> Bool {
        ReadingProgressMatcher.progress(
            in: VoicePrompt.paragraph,
            transcript: transcript
        ).completedWordCount >= VoicePrompt.wordCount
    }
}

enum VoicePrompt {
    static let paragraph = "My best self is just ahead. The life I've always wanted is here. My goals are in reach. I love affirmations."
    static let wordCount = ReadingProgressMatcher.wordCount(in: paragraph)
}
