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
    @StateObject private var heroVideo = HeroVideoPlayer()
    @State private var phoneNumber = ""
    @State private var onboardingStore: OnboardingStore?
    @State private var authError: String?
    @FocusState private var isPhoneNumberFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                LoopingVideoPlayer(player: heroVideo.player)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            AuthPanel(phoneNumberFocused: $isPhoneNumberFocused)
                .environment(\.authActions, AuthActions(
                    phoneNumber: $phoneNumber,
                    authError: authError,
                    continueWithPhone: { openOnboarding(phoneNumber: phoneNumber, email: nil) },
                    continueWithGoogle: { openOnboarding(phoneNumber: nil, email: "google@pika.local") },
                    continueWithEmail: { openOnboarding(phoneNumber: nil, email: "email@pika.local") }
                ))
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
        .task {
            heroVideo.prepareAndPlay()
            prewarmKeyboard()
        }
        .fullScreenCover(item: $onboardingStore) { store in
            OnboardingView(store: store, onDismiss: dismissOnboarding)
                .interactiveDismissDisabled()
        }
    }

    private func openOnboarding(phoneNumber: String?, email: String?) {
        isPhoneNumberFocused = false
        dismissKeyboard()

        do {
            let repository = UserRepository(context: managedObjectContext)
            let user = try repository.findOrCreateUser(phoneNumber: phoneNumber, email: email)
            let step = repository.nextStep(for: user)
            onboardingStore = OnboardingStore(user: user, repository: repository, initialStep: step)
            authError = nil
            heroVideo.pause()
        } catch {
            authError = "Could not open onboarding. Please try again."
        }
    }

    private func dismissOnboarding() {
        resetToLanding()
        onboardingStore = nil
    }

    private func resetToLanding() {
        isPhoneNumberFocused = false
        phoneNumber = ""
        authError = nil
        dismissKeyboard()
        heroVideo.prepareAndPlay()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func prewarmKeyboard() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return }

        let field = UITextField(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        field.keyboardType = .phonePad
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        window.addSubview(field)
        field.becomeFirstResponder()
        DispatchQueue.main.async {
            field.resignFirstResponder()
            field.removeFromSuperview()
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
                    .foregroundStyle(PikaColors.contentDarkTertiary)
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
                .foregroundStyle(PikaColors.contentDarkTertiary)
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
                    .foregroundStyle(PikaColors.textfieldTextColor)
            }
            .frame(width: 76, height: 48)
            .background(
              RoundedRectangle(cornerRadius: 20)
                .fill(PikaColors.surfacelight)
            )

          TextField("Phone number", text: $text)
                .focused(phoneNumberFocused)
                .keyboardType(.phonePad)
                .font(PikaFonts.regular(size: 17, relativeTo: .body))
                .foregroundStyle(PikaColors.textfieldTextColor)
                .frame(height: 48, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .foregroundStyle(PikaColors.contentDarkTertiary)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PikaColors.textfieldColor)
                .stroke(.black.opacity(0.24), lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .frame(height: 58)
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
                .foregroundStyle(PikaColors.contentDarkTertiary)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
