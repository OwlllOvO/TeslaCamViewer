import Foundation
import AVFoundation
import Combine

@MainActor
class MultiAnglePlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var currentSegmentIndex: Int = 0
    @Published var globalProgress: TimeInterval = 0
    @Published var globalDuration: TimeInterval = 0
    @Published private(set) var players: [CameraAngle: AVPlayer] = [:]
    @Published private(set) var detectedFrameRate: Double = 30.0
    @Published private(set) var frameRateMismatchWarning: String?
    @Published var focusedAngle: CameraAngle?

    private var timeObserver: Any?
    private var observingPlayer: AVPlayer?
    private var segments: [ClipSegment] = []
    private var segmentOffsets: [TimeInterval] = []
    private var isAdvancing = false

    var currentSegment: ClipSegment? {
        guard segments.indices.contains(currentSegmentIndex) else { return nil }
        return segments[currentSegmentIndex]
    }

    var eventKeyTimeOffset: TimeInterval? {
        return _eventKeyTimeOffset
    }
    private var _eventKeyTimeOffset: TimeInterval?

    func loadEvent(_ event: TeslaCamEvent) {
        cleanup()
        segments = event.segments
        calculateSegmentOffsets()
        globalDuration = event.totalDuration

        if let eventDate = event.eventTimestamp, let startTime = event.startTime {
            _eventKeyTimeOffset = eventDate.timeIntervalSince(startTime)
            if _eventKeyTimeOffset! < 0 || _eventKeyTimeOffset! > globalDuration {
                _eventKeyTimeOffset = nil
            }
        }

        if !segments.isEmpty {
            loadSegment(at: 0)
        }
    }

    private func calculateSegmentOffsets() {
        segmentOffsets = []
        var offset: TimeInterval = 0
        for segment in segments {
            segmentOffsets.append(offset)
            offset += segment.duration
        }
    }

    func loadSegment(at index: Int) {
        guard segments.indices.contains(index) else { return }
        let wasPlaying = isPlaying
        pause()
        removeTimeObserver()

        let segment = segments[index]
        currentSegmentIndex = index

        var newPlayers: [CameraAngle: AVPlayer] = [:]
        for angle in CameraAngle.allCases {
            if let url = segment.videos[angle] {
                let player = AVPlayer(url: url)
                player.volume = angle == .front ? 1.0 : 0.0
                newPlayers[angle] = player
            }
        }
        players = newPlayers

        detectFrameRates(for: segment)

        setupTimeObserver()
        currentTime = 0
        totalDuration = segment.duration
        updateGlobalProgress()

        if wasPlaying {
            play()
        }
    }

    private static let frameRateMismatchThreshold: Double = 0.5

    private func detectFrameRates(for segment: ClipSegment) {
        Task {
            var ratesByAngle: [CameraAngle: Double] = [:]

            for (angle, url) in segment.videos {
                let asset = AVURLAsset(url: url)
                do {
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    if let track = tracks.first {
                        let fps = try await Double(track.load(.nominalFrameRate))
                        if fps > 0 {
                            ratesByAngle[angle] = fps
                        }
                    }
                } catch {
                    continue
                }
            }

            guard let minRate = ratesByAngle.values.min(),
                  let maxRate = ratesByAngle.values.max() else {
                detectedFrameRate = 30.0
                frameRateMismatchWarning = nil
                return
            }

            detectedFrameRate = maxRate

            if maxRate - minRate > Self.frameRateMismatchThreshold {
                let details = ratesByAngle.map { "\($0.key.displayName): \(String(format: "%.2f", $0.value)) fps" }
                    .sorted()
                    .joined(separator: ", ")
                frameRateMismatchWarning = "Frame rate mismatch: \(details)"
            } else {
                frameRateMismatchWarning = nil
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver, let player = observingPlayer {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        observingPlayer = nil
    }

    private func setupTimeObserver() {
        guard let frontPlayer = players[.front] else { return }

        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        observingPlayer = frontPlayer
        timeObserver = frontPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isAdvancing else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite {
                    self.currentTime = seconds
                    self.updateGlobalProgress()

                    if seconds >= self.totalDuration - 0.05 {
                        self.advanceToNextSegment()
                    }
                }
            }
        }
    }

    private func updateGlobalProgress() {
        if segmentOffsets.indices.contains(currentSegmentIndex) {
            globalProgress = segmentOffsets[currentSegmentIndex] + currentTime
        }
    }

    private func advanceToNextSegment() {
        guard !isAdvancing else { return }
        isAdvancing = true
        defer { isAdvancing = false }

        let nextIndex = currentSegmentIndex + 1
        if nextIndex < segments.count {
            loadSegment(at: nextIndex)
            play()
        } else {
            pause()
            currentTime = totalDuration
            updateGlobalProgress()
        }
    }

    func play() {
        let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
        for (_, player) in players {
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.rate = playbackRate
        }
        isPlaying = true
    }

    func pause() {
        for (_, player) in players {
            player.pause()
        }
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, totalDuration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        for (_, player) in players {
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        currentTime = clampedTime
        updateGlobalProgress()
    }

    func seekGlobal(to time: TimeInterval) {
        let clampedTime = max(0, min(time, globalDuration))
        var accumulated: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            if accumulated + segment.duration > clampedTime || index == segments.count - 1 {
                let localTime = min(clampedTime - accumulated, segment.duration)
                if index != currentSegmentIndex {
                    loadSegment(at: index)
                }
                seek(to: localTime)
                return
            }
            accumulated += segment.duration
        }
    }

    func stepForward() {
        let frameTime: TimeInterval = 1.0 / detectedFrameRate
        let newGlobal = min(globalProgress + frameTime, globalDuration)
        seekGlobal(to: newGlobal)
    }

    func stepBackward() {
        let frameTime: TimeInterval = 1.0 / detectedFrameRate
        let newGlobal = max(globalProgress - frameTime, 0)
        seekGlobal(to: newGlobal)
    }

    func skipForward(_ seconds: TimeInterval = 10) {
        let newGlobal = min(globalProgress + seconds, globalDuration)
        seekGlobal(to: newGlobal)
    }

    func skipBackward(_ seconds: TimeInterval = 10) {
        let newGlobal = max(globalProgress - seconds, 0)
        seekGlobal(to: newGlobal)
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            for (_, player) in players {
                player.rate = rate
            }
        }
    }

    func cleanup() {
        pause()
        removeTimeObserver()
        players.removeAll()
        segments = []
        segmentOffsets = []
        currentTime = 0
        totalDuration = 0
        globalProgress = 0
        globalDuration = 0
        _eventKeyTimeOffset = nil
        isAdvancing = false
        detectedFrameRate = 30.0
        frameRateMismatchWarning = nil
    }
}
