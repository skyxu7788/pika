//
//  CompleteStep.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation
import SwiftUI
import AVFoundation
import UIKit

struct CompleteStep: View {
    @StateObject private var store: CompleteStepStore

    init(store: CompleteStepStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: PikaColors.profileCardBackground,
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()

            if let profile = store.profile {
                VStack(spacing: 18) {
                    PikaIDCardView(profile: profile)
                        .frame(width: 250, height: 450)
                        .padding(.top, 92)
                        .rotationEffect(.degrees(2.2))

                    VStack(spacing: 6) {
                        Text("MEET SEMI")
                            .font(PikaFonts.extendedBlack(size: 42, relativeTo: .largeTitle))
                            .foregroundStyle(.black.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text("Your AI Self is ready to chat")
                            .font(PikaFonts.regular(size: 21, relativeTo: .title3))
                            .foregroundStyle(.black)
                    }

                    VStack(spacing: 14) {
                        CompleteActionButton(title: "Open Messages", systemName: "arrow.up.right", style: .primary)
                        CompleteActionButton(title: "Share ID Card", systemName: "square.and.arrow.up", style: .secondary)
                    }
                }
                .padding(.horizontal, 28)
            } else {
                Text(store.errorMessage ?? "Loading your profile...")
                    .font(PikaFonts.regular(size: 18, relativeTo: .body))
                    .foregroundStyle(.black.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(28)
            }

            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 62, height: 62)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(PikaColors.surfaceDark.opacity(0.05))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(PikaColors.textfieldColor, lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 26)
            .padding(.trailing, 28)
        }
    }
}

private struct PikaIDCardView: View {
    let profile: CompleteStepProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                capturedPhoto

                Spacer(minLength: 8)

                PikaMark()
                    .frame(width: 36, height: 24)
                    .padding(.top, 6)
            }

            Text(profile.displayName)
                .font(PikaFonts.extendedBlack(size: 19, relativeTo: .title3))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 16)

            Rectangle()
                .fill(.black)
                .frame(height: 2)
                .padding(.top, 3)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 11) {
                    IDFact(label: "BORN ON PIKA", value: profile.updatedAt.pikaIDDate)
                    IDFact(label: "LOCATION", value: profile.location.uppercased())
                    IDFact(label: "STATUS", value: profile.status.uppercased())
                    IDFact(label: "FIND ME ON", value: profile.publicProfilePath)
                }

                Spacer(minLength: 6)

                Image("barcode")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 146, height: 30)
                    .rotationEffect(.degrees(90))
                    .frame(width: 30, height: 146)
                    .clipped()
            }
            .padding(.top, 10)
          
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(width: 250, height: 450, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 1.0, green: 0.995, blue: 0.97))
                .shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.92), lineWidth: 1)
                }
        }
    }

    private var capturedPhoto: some View {
        Group {
            if let photoData = profile.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.06)
                    .overlay {
                        Image(systemName: "person.crop.square")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(.black.opacity(0.34))
                    }
            }
        }
        .frame(width: 138, height: 188)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        }
    }

}

private struct IDFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("SpaceMono-Bold", size: 7, relativeTo: .caption2))
                .foregroundStyle(.black)

            Text(value)
                .font(.custom("SpaceMono-Regular", size: 8.5, relativeTo: .caption))
                .foregroundStyle(.black.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: 132, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
                .offset(y: 6)
        }
    }
}

private struct PikaMark: View {
    var body: some View {
        Image("logo")
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(.black)
            .rotationEffect(.degrees(8))
            .scaleEffect(x: 1.08, y: 0.72)
    }
}

private enum CompleteActionButtonStyle {
    case primary
    case secondary
}

private struct CompleteActionButton: View {
    let title: String
    let systemName: String
    let style: CompleteActionButtonStyle

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Text(title)
                    .font(PikaFonts.regular(size: 19, relativeTo: .headline))
                    .fontWeight(.bold)

                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .bold))
            }
            .foregroundStyle(style == .primary ? .white : Color.black.opacity(0.86))
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                style == .primary ? Color.black.opacity(0.86) : Color(red: 0.93, green: 0.9, blue: 0.85),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Date {
    var pikaIDDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self).uppercased()
    }
}

struct CompleteStep_Previews: PreviewProvider {
    static var previews: some View {
        PreviewContainer()
    }

    private static let previewProfile = CompleteStepProfile(
        userId: "preview-user-id",
        updatedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 29)) ?? Date(),
        location: "San Francisco, CA",
        status: "Alive",
        photoData: UIImage(named: "profileImage")?.pngData()
    )

    private struct PreviewContainer: View {
        var body: some View {
            CompleteStep(store: CompleteStepStore(profile: previewProfile))
                .onAppear {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
        }
    }
}
