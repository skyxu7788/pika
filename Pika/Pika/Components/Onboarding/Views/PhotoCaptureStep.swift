//
//  PhotoCaptureStep.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation
import SwiftUI
import AVFoundation

struct PhotoCaptureStep: View {
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

private struct UnavailableState: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black

            Text(message)
                .font(PikaFonts.regular(size: 16, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .padding(28)
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
