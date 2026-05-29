//
//  ContentView.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import SwiftUI
import AVFoundation
import AVKit
import CoreData
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var heroVideo = HeroVideoPlayer()
    @State private var phoneNumber = ""
    @State private var onboardingStore: OnboardingStore?
    @State private var authError: String?
    @FocusState private var isPhoneNumberFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ZStack {
                    Color(red: 0.96, green: 0.96, blue: 0.95)

                    LoopingVideoPlayer(player: heroVideo.player)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isPhoneNumberFocused = false
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: max(285, proxy.size.height * 0.48))

                    AuthPanel(phoneNumberFocused: $isPhoneNumberFocused)
                        .environment(\.authActions, AuthActions(
                            phoneNumber: $phoneNumber,
                            authError: authError,
                            continueWithPhone: { openOnboarding(phoneNumber: phoneNumber, email: nil) },
                            continueWithGoogle: { openOnboarding(phoneNumber: nil, email: "google@pika.local") },
                            continueWithEmail: { openOnboarding(phoneNumber: nil, email: "email@pika.local") }
                        ))
                        .padding(.horizontal, 28)
                        .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 18))
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard value.translation.height > 20 else { return }
                        isPhoneNumberFocused = false
                    }
            )
        }
        .task {
            heroVideo.play()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                heroVideo.play()
            case .inactive, .background:
                heroVideo.pause()
            @unknown default:
                heroVideo.pause()
            }
        }
        .fullScreenCover(item: $onboardingStore, onDismiss: {
            heroVideo.play()
        }) { store in
            OnboardingView(store: store) {
                onboardingStore = nil
            }
        }
    }

    private func openOnboarding(phoneNumber: String?, email: String?) {
        do {
            let repository = UserRepository(context: managedObjectContext)
            let user = try repository.findOrCreateUser(phoneNumber: phoneNumber, email: email)
            let step = repository.nextStep(for: user)
            onboardingStore = OnboardingStore(user: user, context: managedObjectContext, initialStep: step)
            authError = nil
            heroVideo.pause()
        } catch {
            authError = "Could not open onboarding. Please try again."
        }
    }
}

private struct AuthPanel: View {
    @Environment(\.authActions) private var authActions
    let phoneNumberFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("YOUR AI SELF IS\nWAITING")
                    .font(PikaFonts.extendedBlack(size: 37, relativeTo: .largeTitle))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sign up or log in below")
                    .font(PikaFonts.regular(size: 17, relativeTo: .body))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            PhoneNumberField(text: authActions.phoneNumber, phoneNumberFocused: phoneNumberFocused)

            ContinueButton()

            if let authError = authActions.authError {
                Text(authError)
                    .font(PikaFonts.regular(size: 13, relativeTo: .caption))
                    .foregroundStyle(.red.opacity(0.8))
            }

            DividerLabel()
                .padding(.top, 6)

            HStack(spacing: 20) {
                SocialButton(systemName: nil, text: "G", action: authActions.continueWithGoogle)
                SocialButton(systemName: "envelope.fill", text: nil, action: authActions.continueWithEmail)
            }
            .padding(.top, 2)

            Text("Sign in to agree to terms")
                .font(PikaFonts.regular(size: 14, relativeTo: .footnote))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        }
    }
}

private struct PhoneNumberField: View {
    @Binding var text: String
    let phoneNumberFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Text("🇺🇸")
                    .font(.system(size: 16))

                Text("+1")
                    .font(PikaFonts.regular(size: 16, relativeTo: .body))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, height: 56)
            .background(
                Capsule()
                    .fill(.white.opacity(0.72))
            )

            TextField("Phone number", text: $text)
                .focused(phoneNumberFocused)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .font(PikaFonts.regular(size: 20, relativeTo: .body))
                .foregroundStyle(.primary)
                .tint(.black)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .onChange(of: text) { _, newValue in
                    let digitCount = newValue.filter(\.isNumber).count
                    if digitCount >= 10 {
                        phoneNumberFocused.wrappedValue = false
                    }
                }
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.38))
                .stroke(.black.opacity(0.24), lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            phoneNumberFocused.wrappedValue = true
        }
    }
}

private struct AuthActions {
    var phoneNumber: Binding<String>
    var authError: String?
    var continueWithPhone: () -> Void
    var continueWithGoogle: () -> Void
    var continueWithEmail: () -> Void
}

private struct ContinueButton: View {
    @Environment(\.authActions) private var authActions

    var body: some View {
        Button(action: authActions.continueWithPhone) {
            Text("Continue")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.78, green: 0.70, blue: 1.0))
        )
    }
}

private struct DividerLabel: View {
    var body: some View {
        HStack(spacing: 18) {
            Rectangle()
                .fill(.black.opacity(0.06))
                .frame(height: 1)

            Text("Or continue with")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()

            Rectangle()
                .fill(.black.opacity(0.06))
                .frame(height: 1)
        }
    }
}

private struct SocialButton: View {
    let systemName: String?
    let text: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                    .frame(width: 78, height: 78)

                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(PikaColors.contentDarkTertiary)
                } else if let text {
                    Text(text)
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(PikaColors.contentDarkTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text == "G" ? "Continue with Google" : "Continue with email")
    }
}

private struct AuthActionsKey: EnvironmentKey {
    static var defaultValue = AuthActions(
        phoneNumber: .constant(""),
        authError: nil,
        continueWithPhone: {},
        continueWithGoogle: {},
        continueWithEmail: {}
    )
}

private extension EnvironmentValues {
    var authActions: AuthActions {
        get { self[AuthActionsKey.self] }
        set { self[AuthActionsKey.self] = newValue }
    }
}

private final class HeroVideoPlayer: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init() {
        guard let url = Bundle.main.url(forResource: "AppHeroVideo-1080x1920-5k", withExtension: "mp4") else {
            return
        }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 1

        player.isMuted = true
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}

private struct LoopingVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.needsDisplayOnBoundsChange = false
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
