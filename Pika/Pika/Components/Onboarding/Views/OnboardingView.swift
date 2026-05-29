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
        .background(PikaColors.onboardingBackground)
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
