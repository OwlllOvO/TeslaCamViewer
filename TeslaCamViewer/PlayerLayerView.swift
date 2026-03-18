import SwiftUI
import AVFoundation
import AppKit

struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.setPlayer(player)
        return view
    }

    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        nsView.setPlayer(player)
    }
}

class PlayerNSView: NSView {
    private var playerLayer: AVPlayerLayer

    override init(frame frameRect: NSRect) {
        playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func setPlayer(_ player: AVPlayer?) {
        playerLayer.player = player
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}
