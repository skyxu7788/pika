//
//  VoiceCaptureStep.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation
import SwiftUI
import AVFoundation

struct VoiceCaptureStep: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 128)

            Text("MAKE YOUR\nAI SELF SOUND\nLIKE YOU")
                .font(PikaFonts.extendedBlack(size: 37, relativeTo: .largeTitle))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text("Read the text below to clone your\nvoice and create an\nAI Self that talks like you.")
                .font(PikaFonts.regular(size: 17, relativeTo: .body))
                .foregroundStyle(PikaColors.contentDarkTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)

            Spacer()

            readingProgressText
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.horizontal, 20)

            Spacer()

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(PikaFonts.regular(size: 13, relativeTo: .caption))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
            }

            voiceControls
                .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColors.onboardingBackground)
    }

    @ViewBuilder
    private var voiceControls: some View {
        if store.isVoiceReadyForReview {
            HStack(spacing: 60) {
                ReviewControlButton(systemName: "arrow.counterclockwise", action: store.retryVoiceRecording)

                Button(action: store.confirmVoiceRecording) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 90, height: 90)
                        .background(Color(red: 0.78, green: 0.70, blue: 1.0), in: Circle())
                }
                .buttonStyle(.plain)

                ReviewControlButton(systemName: "play.fill", action: store.playRecordedAudio)
            }
        } else {
            Button {
                store.toggleRecording()
            } label: {
                Circle()
                    .fill(Color(red: 0.78, green: 0.70, blue: 1.0))
                    .frame(width: 90, height: 90)
                    .overlay {
                        Circle()
                            .fill(store.isRecording ? .red : .black)
                            .frame(width: store.isRecording ? 30 : 22, height: store.isRecording ? 30 : 22)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var readingProgressText: Text {
        let progress = ReadingProgressMatcher.progress(
            in: VoicePrompt.paragraph,
            transcript: store.transcript
        )
        let remainingColor = PikaColors.unrecordedPrompt
        let completedColor = Color(red: 0.37, green: 0.27, blue: 0.74)

        if progress.completedWordCount >= VoicePrompt.wordCount {
            return Text(VoicePrompt.paragraph)
                .foregroundStyle(completedColor)
        }

        guard let completedRange = progress.completedRange else {
            return Text(VoicePrompt.paragraph)
                .foregroundStyle(remainingColor)
        }

        let completed = String(VoicePrompt.paragraph[completedRange])
        let remaining = String(VoicePrompt.paragraph[completedRange.upperBound...])

        return Text(completed)
            .foregroundStyle(completedColor)
        + Text(remaining)
            .foregroundStyle(remainingColor)
    }

}

private struct ReviewControlButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(PikaColors.contentDarkTertiary)
                .frame(width: 70, height: 70)
                .background(.black.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct VoiceCaptureStep_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCaptureStep(store: previewStore())
            .previewDisplayName("Review")
    }

    private static func previewStore(
        transcript: String = VoicePrompt.paragraph,
        isVoiceReadyForReview: Bool = true
    ) -> OnboardingStore {
        let controller = PersistenceController(inMemory: true)
        let user = User(context: controller.container.viewContext)
        user.userId = UUID().uuidString
        user.location = "San Francisco, CA"
        user.status = "Alive"
        user.createdAt = Date()
        user.updatedAt = Date()

        let store = OnboardingStore(
            user: user,
            repository: UserRepository(context: controller.container.viewContext),
            initialStep: .voice
        )
        store.transcript = transcript
        store.isVoiceReadyForReview = isVoiceReadyForReview
        return store
    }
}
