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
                .font(PikaFonts.extendedMedium(size: 28, relativeTo: .title2))
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
        .background(PikaColors.surfacelight)
    }

    @ViewBuilder
    private var voiceControls: some View {
        if store.isVoiceReadyForReview {
            HStack(spacing: 60) {
              ReviewControlButton(name: "switch", action: store.retryVoiceRecording)

              Button(action: {
                store.confirmVoiceRecording()
              }, label: {
                Circle()
                  .fill(PikaColors.accentPrimary)
                  .frame(width: 80, height: 80)
                  .overlay {
                    Image("checkmark")
                      .resizable()
                      .scaledToFit()
                      .frame(width: 20, height: 20)
                  }
              })
              .buttonStyle(.plain)

              ReviewControlButton(name: "play", action: store.playRecordedAudio)
            }
        } else {
            VStack(spacing: 15) {
                Button {
                    store.toggleRecording()
                } label: {
                    if !store.isRecording {
                        Circle()
                            .fill(PikaColors.accentPrimary)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Circle()
                                    .fill(.black)
                                    .frame(width: 20, height: 20)
                            }
                    } else {
                        Circle()
                            .fill(PikaColors.accentQuatenry)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Circle()
                                    .fill(PikaColors.accentDark)
                                    .frame(width: 20, height: 20)
                            }
                    }
                }
                .buttonStyle(.plain)

                if store.isRecording {
                    Text("Listening...")
                        .font(PikaFonts.medium(size: 12, relativeTo: .body))
                        .foregroundStyle(PikaColors.contentDarkTertiary)
                }
            }
        }
    }

    private var readingProgressText: Text {
        let progress = store.readingProgress
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
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
          Circle()
            .fill(PikaColors.contentDarkTertiary.opacity(0.05))
            .frame(width: 48, height: 48)
            .overlay {
              Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            }
        }
        .buttonStyle(.plain)
    }
}

struct VoiceCaptureStep_Previews: PreviewProvider {
    static var previews: some View {
        Group {
          VoiceCaptureStep(store: previewStore(isVoiceReadyForReview: false, isRecording: false))
              .previewDisplayName("Not Recording")

          VoiceCaptureStep(store: previewStore(isVoiceReadyForReview: false, isRecording: true))
              .previewDisplayName("Recording")

          VoiceCaptureStep(store: previewStore())
              .previewDisplayName("Review")
        }
    }

    private static func previewStore(
        transcript: String = VoicePrompt.paragraph,
        isVoiceReadyForReview: Bool = true,
        isRecording: Bool = false
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
        store.readingProgress = ReadingProgressMatcher.progress(
            in: VoicePrompt.paragraph,
            transcript: transcript
        )
        store.isVoiceReadyForReview = isVoiceReadyForReview
        store.isRecording = isRecording
        return store
    }
}
