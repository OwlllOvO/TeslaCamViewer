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
    private var endOfItemObservers: [NSObjectProtocol] = []
    private var finishedPlayers: Set<CameraAngle> = []
    private var playerDurations: [CameraAngle: TimeInterval] = [:]
    private var longestAngle: CameraAngle?

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
                player.actionAtItemEnd = .pause
                newPlayers[angle] = player
            }
        }
        players = newPlayers

        detectFrameRates(for: segment)
        loadPlayerDurations(for: segment)

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
        removeEndOfItemObservers()
    }

    private func setupTimeObserver() {
        playerDurations = [:]
        finishedPlayers = []
        longestAngle = players.keys.contains(.front) ? .front : players.keys.first

        guard let primary = longestAngle, let primaryPlayer = players[primary] else { return }

        setupTimeObserverOn(primaryPlayer)
        setupEndOfItemObservers()
    }

    private func loadPlayerDurations(for segment: ClipSegment) {
        let currentIdx = currentSegmentIndex
        Task {
            var durations: [CameraAngle: TimeInterval] = [:]

            for (angle, url) in segment.videos {
                let asset = AVURLAsset(url: url)
                do {
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    if seconds.isFinite && seconds > 0 {
                        durations[angle] = seconds
                    }
                } catch {
                    continue
                }
            }

            guard self.currentSegmentIndex == currentIdx else { return }

            self.playerDurations = durations

            var maxDur: TimeInterval = 0
            var longest: CameraAngle?
            for (angle, dur) in durations {
                if dur > maxDur {
                    maxDur = dur
                    longest = angle
                }
            }

            if let longest {
                let previousLongest = self.longestAngle
                self.longestAngle = longest

                if previousLongest != longest, let player = self.players[longest] {
                    self.removeTimeObserver()
                    self.setupTimeObserverOn(player)
                    self.setupEndOfItemObservers()
                    if self.isPlaying {
                        player.rate = self.playbackRate
                    }
                }
            }
        }
    }

    private func setupTimeObserverOn(_ player: AVPlayer) {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        observingPlayer = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
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

    private func setupEndOfItemObservers() {
        for (angle, player) in players {
            guard let item = player.currentItem else { continue }
            if angle == longestAngle { continue }

            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self, angle] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.finishedPlayers.insert(angle)
                    // Seek back to the last frame so the player shows its final image
                    if let dur = self.playerDurations[angle] {
                        let lastFrame = CMTime(seconds: dur - 0.01, preferredTimescale: 600)
                        self.players[angle]?.seek(to: lastFrame, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            }
            endOfItemObservers.append(observer)
        }
    }

    private func removeEndOfItemObservers() {
        for observer in endOfItemObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        endOfItemObservers.removeAll()
        finishedPlayers.removeAll()
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
        } else {
            pause()
            currentTime = totalDuration
            updateGlobalProgress()
        }
    }

    func play() {
        let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
        for (angle, player) in players {
            let angleDur = playerDurations[angle] ?? totalDuration
            if currentTime >= angleDur - 0.05 {
                let lastFrame = CMTime(seconds: angleDur - 0.01, preferredTimescale: 600)
                player.seek(to: lastFrame, toleranceBefore: .zero, toleranceAfter: .zero)
                player.pause()
                finishedPlayers.insert(angle)
            } else {
                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                player.rate = playbackRate
            }
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
        finishedPlayers.removeAll()
        for (angle, player) in players {
            let angleDur = playerDurations[angle] ?? totalDuration
            if clampedTime >= angleDur - 0.05 {
                let lastFrame = CMTime(seconds: angleDur - 0.01, preferredTimescale: 600)
                player.seek(to: lastFrame, toleranceBefore: .zero, toleranceAfter: .zero)
                finishedPlayers.insert(angle)
            } else {
                let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
                player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
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
            for (angle, player) in players {
                if !finishedPlayers.contains(angle) {
                    player.rate = rate
                }
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
        playerDurations = [:]
        longestAngle = nil
        finishedPlayers = []
    }
}
