import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var controller: MultiAnglePlayerController

    private let speeds: [Float] = [0.5, 1, 2, 4, 8, 16]

    var body: some View {
        VStack(spacing: 8) {
            progressBar
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                transportControls
                Spacer()
                timeDisplay
                Spacer()
                speedControls
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
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

    private var timeDisplay: some View {
        Text("\(formatTime(controller.globalProgress)) / \(formatTime(controller.globalDuration))")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var speedControls: some View {
        HStack(spacing: 3) {
            ForEach(speeds, id: \.self) { speed in
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
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
