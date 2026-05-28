//
//  OnboardingView.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import AVFoundation
import CoreData
import SwiftUI
import UIKit

enum OnboardingStep {
    case photo
    case voice
    case complete

    var progress: CGFloat {
        switch self {
        case .photo:
            0.5
        case .voice:
            2.0 / 3.0
        case .complete:
            1.0
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            switch store.currentStep {
            case .photo:
                PhotoCaptureStep(store: store)
                    .transition(.opacity)
            case .voice:
                VoiceCaptureStep(store: store)
                    .transition(.opacity)
            case .complete:
                CompleteStep()
                    .transition(.opacity)
            }

            OnboardingNavigationBar(
                progress: store.currentStep.progress,
                backAction: {
                    if !store.goBack() {
                        onDismiss()
                    }
                }
            )
            .padding(.top, 18)
        }
        .animation(.easeInOut(duration: 0.2), value: store.currentStep.progress)
        .onDisappear {
            store.stopRecordingIfNeeded()
        }
    }
}

private struct OnboardingNavigationBar: View {
    let progress: CGFloat
    let backAction: () -> Void

    var body: some View {
        HStack {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 54, height: 54)
                    .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            ProgressPill(progress: progress)
                .frame(width: 178, height: 3)

            Spacer()

            Color.clear
                .frame(width: 54, height: 54)
        }
        .padding(.horizontal, 14)
    }
}

private struct ProgressPill: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.08))

                Capsule()
                    .fill(Color(red: 0.78, green: 0.70, blue: 1.0))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
    }
}

private struct PhotoCaptureStep: View {
    @ObservedObject var store: OnboardingStore
    @StateObject private var camera = CameraController()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                CameraPreview(session: camera.session)
                    .overlay {
                        if let errorMessage = camera.errorMessage {
                            UnavailableState(message: errorMessage)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .ignoresSafeArea()

                HStack {
                    PhotoControlButton(systemName: "photo")

                    Spacer()

                    Button {
                        camera.capturePhoto { data in
                            store.savePhoto(data)
                        }
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 94, height: 94)
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.45), lineWidth: 8)
                            }
                            .overlay {
                                Circle()
                                    .stroke(.black.opacity(0.12), lineWidth: 2)
                                    .padding(8)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.errorMessage != nil)

                    Spacer()

                    PhotoControlButton(systemName: "arrow.triangle.2.circlepath.camera") {
                        camera.flipCamera()
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, max(42, proxy.safeAreaInsets.bottom + 26))
            }
            .background(.black)
        }
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

private struct PhotoControlButton: View {
    let systemName: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(.black.opacity(0.64), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct VoiceCaptureStep: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 128)

            Text("MAKE YOUR\nAI SELF SOUND\nLIKE YOU")
                .font(.custom("Telka-ExtendedBlack", size: 38, relativeTo: .largeTitle))
                .fontWeight(.black)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.74)

            Text("Read the text below to clone your\nvoice and create an\nAI Self that talks like you.")
                .font(.custom("Telka-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(.secondary)
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
                    .font(.custom("Telka-Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
            }

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
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
    }

    private var readingProgressText: Text {
        let progress = ReadingProgressMatcher.progress(
            in: Self.paragraph,
            transcript: store.transcript
        )
        let remainingColor = Color(red: 0.66, green: 0.58, blue: 0.92)
        let completedColor = Color(red: 0.37, green: 0.27, blue: 0.74)

        guard let completedRange = progress.completedRange else {
            return Text(Self.paragraph)
                .foregroundStyle(remainingColor)
        }

        let completed = String(Self.paragraph[completedRange])
        let remaining = String(Self.paragraph[completedRange.upperBound...])

        return Text(completed)
            .foregroundStyle(completedColor)
        + Text(remaining)
            .foregroundStyle(remainingColor)
    }

    private static let paragraph = "My best self is just ahead. The life I've always wanted is here. My goals are in reach. I love affirmations."
}

private struct CompleteStep: View {
    var body: some View {
        Color(red: 0.97, green: 0.96, blue: 0.94)
            .ignoresSafeArea()
    }
}

private struct UnavailableState: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black

            Text(message)
                .font(.custom("Telka-Regular", size: 16, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .padding(28)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let controller = PersistenceController(inMemory: true)
        let user = User(context: controller.container.viewContext)
        user.userId = UUID().uuidString
        user.createdAt = Date()
        user.updatedAt = Date()

        return OnboardingView(
            store: OnboardingStore(user: user, context: controller.container.viewContext, initialStep: .voice),
            onDismiss: {}
        )
    }
}
