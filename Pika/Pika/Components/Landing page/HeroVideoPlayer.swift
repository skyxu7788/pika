//
//  HeroVideoPlayer.swift
//  Pika
//
//  Created by S J on 5/30/26.
//

import Foundation
import UIKit
import SwiftUI
import AVFoundation

final class HeroVideoPlayer: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var loadTask: Task<Void, Never>?

    init() {
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
    }

    func prepareAndPlay() {
        if looper != nil {
            player.play()
            return
        }
        if loadTask != nil { return }

        loadTask = Task.detached(priority: .utility) { [player] in
            guard let url = Bundle.main.url(
                forResource: "AppHeroVideo-1080x1920-5k",
                withExtension: "mp4"
            ) else { return }

            let asset = AVURLAsset(url: url)
            _ = try? await asset.load(.tracks, .duration)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 1

            await MainActor.run {
                self.looper = AVPlayerLooper(player: player, templateItem: item)
                player.play()
            }
        }
    }

    func pause() {
        player.pause()
    }
}

struct LoopingVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .white
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

final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
