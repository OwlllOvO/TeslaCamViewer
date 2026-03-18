import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var controller: MultiAnglePlayerController
    var event: TeslaCamEvent?

    private let speeds: [Float] = [0.5, 1, 2, 4, 8, 16]

    var body: some View {
        VStack(spacing: 8) {
            if let warning = controller.frameRateMismatchWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 8) {
                Text(formatTime(controller.globalProgress))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 68, alignment: .trailing)

                progressBar

                Text(formatTime(controller.globalDuration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 68, alignment: .leading)
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                let sideWidth = max(0, (geo.size.width - 200) / 2)

                ZStack {
                    transportControls

                    HStack(spacing: 0) {
                        eventInfoSection
                            .frame(width: sideWidth, alignment: .leading)
                            .clipped()

                        Spacer(minLength: 0)

                        speedControls(maxWidth: sideWidth)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var eventInfoSection: some View {
        if let info = event?.eventInfo {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    if let city = info.city {
                        Label(city, systemImage: "building.2")
                    }
                    if let street = info.street {
                        Label(street, systemImage: "road.lanes")
                    }
                    if let lat = info.est_lat, let lon = info.est_lon {
                        Label("\(lat), \(lon)", systemImage: "location")
                    }
                }
                Label(info.reasonDisplayName, systemImage: "exclamationmark.triangle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height / 2
            ZStack {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: width, height: 4)
                    .position(x: width / 2, y: midY)

                Capsule()
                    .fill(.tint)
                    .frame(width: progressWidth(in: width), height: 4)
                    .position(x: progressWidth(in: width) / 2, y: midY)

                if let keyOffset = controller.eventKeyTimeOffset, controller.globalDuration > 0 {
                    let fraction = keyOffset / controller.globalDuration
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: .red.opacity(0.5), radius: 3)
                        .position(x: width * fraction, y: midY)
                        .help("Event key moment")
                }

                Circle()
                    .fill(.white)
                    .shadow(radius: 2)
                    .frame(width: 14, height: 14)
                    .position(x: progressWidth(in: width), y: midY)
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let time = fraction * controller.globalDuration
                        controller.seekGlobal(to: time)
                    }
            )
        }
        .frame(height: 14)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard controller.globalDuration > 0 else { return 0 }
        let fraction = controller.globalProgress / controller.globalDuration
        return CGFloat(max(0, min(1, fraction))) * totalWidth
    }

    private var transportControls: some View {
        HStack(spacing: 6) {
            controlButton("gobackward.10", help: "Skip back 10s (←)") {
                controller.skipBackward(10)
            }
            controlButton("backward.frame", help: "Previous frame (,)") {
                controller.stepBackward()
            }
            Button(action: { controller.togglePlayback() }) {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(controller.isPlaying ? "Pause (Space)" : "Play (Space)")

            controlButton("forward.frame", help: "Next frame (.)") {
                controller.stepForward()
            }
            controlButton("goforward.10", help: "Skip forward 10s (→)") {
                controller.skipForward(10)
            }
        }
    }

    private func controlButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private static let speedButtonWidth: CGFloat = 40
    private static let speedButtonSpacing: CGFloat = 3

    private func visibleSpeeds(maxWidth: CGFloat) -> [Float] {
        let count = max(0, Int((maxWidth + Self.speedButtonSpacing) / (Self.speedButtonWidth + Self.speedButtonSpacing)))
        guard count > 0 else { return [] }
        let oneXIndex = speeds.firstIndex(of: 1) ?? 0
        if count > oneXIndex {
            return Array(speeds.prefix(count))
        }
        return Array(speeds.suffix(from: oneXIndex).prefix(count))
    }

    private func speedControls(maxWidth: CGFloat) -> some View {
        let visible = visibleSpeeds(maxWidth: maxWidth)
        return HStack(spacing: Self.speedButtonSpacing) {
            ForEach(visible, id: \.self) { speed in
                Button(action: { controller.setRate(speed) }) {
                    Text(speedLabel(speed))
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            controller.playbackRate == speed
                                ? AnyShapeStyle(.tint.opacity(0.8))
                                : AnyShapeStyle(.quaternary)
                        )
                        .foregroundStyle(controller.playbackRate == speed ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return "\(Int(speed))x"
        }
        return String(format: "%.1fx", speed)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00:00" }
        let fps = controller.detectedFrameRate
        let totalFrames = Int(round(seconds * fps))
        let framesPerSecond = Int(round(fps))
        let frame = totalFrames % framesPerSecond
        let totalSeconds = totalFrames / framesPerSecond
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", minutes, secs, frame)
    }
}
