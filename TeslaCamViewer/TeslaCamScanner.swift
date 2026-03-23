import Foundation
import AVFoundation

@MainActor
class TeslaCamScanner: ObservableObject {
    @Published var events: [TeslaCamEvent] = []
    @Published var isLoading = false

    private let fileManager = FileManager.default
    private var watchedURL: URL?
    private var directoryWatcher: DirectoryWatcher?
    private var rescanTask: Task<Void, Never>?

    func removeEvent(_ event: TeslaCamEvent) {
        events.removeAll { $0.id == event.id }
    }

    func stopWatching() {
        directoryWatcher?.stop()
        directoryWatcher = nil
        rescanTask?.cancel()
        rescanTask = nil
        watchedURL = nil
    }

    func scanDirectory(_ url: URL) async {
        isLoading = true
        defer { isLoading = false }

        let folderType = detectFolderType(url)
        var allEvents: [TeslaCamEvent] = []

        switch folderType {
        case .teslaCam:
            let subfolders = ["RecentClips", "SavedClips", "SentryClips"]
            for subfolder in subfolders {
                let subURL = url.appendingPathComponent(subfolder)
                if fileManager.fileExists(atPath: subURL.path) {
                    var events = await scanClipsFolder(subURL)
                    for i in events.indices {
                        events[i].sourceFolder = subfolder
                    }
                    allEvents.append(contentsOf: events)
                }
            }
        case .recentClips, .sentryClips, .savedClips:
            allEvents = await scanClipsFolder(url)
        case .singleEvent:
            if let event = await scanEventFolder(url) {
                allEvents.append(event)
            }
        }

        events = allEvents.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }

        startWatching(url)
    }

    private func startWatching(_ url: URL) {
        stopWatching()
        watchedURL = url

        let folderType = detectFolderType(url)
        var pathsToWatch: [String] = [url.path]

        if folderType == .teslaCam {
            for subfolder in ["RecentClips", "SavedClips", "SentryClips"] {
                let subURL = url.appendingPathComponent(subfolder)
                if fileManager.fileExists(atPath: subURL.path) {
                    pathsToWatch.append(subURL.path)
                }
            }
        }

        directoryWatcher = DirectoryWatcher(paths: pathsToWatch) { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleRescan()
            }
        }
        directoryWatcher?.start()
    }

    private func scheduleRescan() {
        rescanTask?.cancel()
        rescanTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let url = watchedURL else { return }
            await rescanDirectory(url)
        }
    }

    private func rescanDirectory(_ url: URL) async {
        let folderType = detectFolderType(url)
        var allEvents: [TeslaCamEvent] = []

        switch folderType {
        case .teslaCam:
            let subfolders = ["RecentClips", "SavedClips", "SentryClips"]
            for subfolder in subfolders {
                let subURL = url.appendingPathComponent(subfolder)
                if fileManager.fileExists(atPath: subURL.path) {
                    var events = await scanClipsFolder(subURL)
                    for i in events.indices {
                        events[i].sourceFolder = subfolder
                    }
                    allEvents.append(contentsOf: events)
                }
            }
        case .recentClips, .sentryClips, .savedClips:
            allEvents = await scanClipsFolder(url)
        case .singleEvent:
            if let event = await scanEventFolder(url) {
                allEvents.append(event)
            }
        }

        let newEvents = allEvents.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
        let oldPaths = Set(events.map(\.folderURL.path))
        let newPaths = Set(newEvents.map(\.folderURL.path))
        if oldPaths != newPaths {
            events = newEvents
        }
    }

    private func detectFolderType(_ url: URL) -> FolderType {
        let name = url.lastPathComponent
        if name == "TeslaCam" {
            return .teslaCam
        }
        if name == "RecentClips" {
            return .recentClips
        }
        if name == "SavedClips" {
            return .savedClips
        }
        if name == "SentryClips" {
            return .sentryClips
        }

        let contents = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
        let hasSubEvents = contents.contains { item in
            var isDir: ObjCBool = false
            let path = url.appendingPathComponent(item).path
            return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
                && item.contains("-") && !item.hasPrefix(".")
        }
        let hasVideos = contents.contains { $0.hasSuffix(".mp4") }

        if hasVideos {
            return .singleEvent
        }
        if hasSubEvents {
            return .savedClips
        }
        return .singleEvent
    }

    private func scanClipsFolder(_ url: URL) async -> [TeslaCamEvent] {
        let name = url.lastPathComponent
        var events: [TeslaCamEvent] = []

        if name == "RecentClips" {
            if let event = await scanEventFolder(url) {
                events.append(event)
            }
            return events
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return events
        }

        for item in contents {
            let itemURL = url.appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue {
                if let event = await scanEventFolder(itemURL) {
                    events.append(event)
                }
            }
        }

        return events
    }

    private func scanEventFolder(_ url: URL) async -> TeslaCamEvent? {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return nil
        }

        let mp4Files = contents.filter { $0.hasSuffix(".mp4") }
        if mp4Files.isEmpty { return nil }

        let eventInfo = loadEventInfo(from: url)
        let thumbURL: URL? = contents.contains("thumb.png")
            ? url.appendingPathComponent("thumb.png") : nil

        let segmentGroups = groupVideosByTimestamp(mp4Files, baseURL: url)
        var segments: [ClipSegment] = []

        for (timestamp, videos) in segmentGroups.sorted(by: { $0.key < $1.key }) {
            let duration = await getMaxVideoDuration(videos)
            segments.append(ClipSegment(
                timestamp: timestamp,
                videos: videos,
                duration: duration
            ))
        }

        segments.sort { $0.timestamp < $1.timestamp }

        guard !segments.isEmpty else { return nil }

        return TeslaCamEvent(
            folderURL: url,
            eventInfo: eventInfo,
            segments: segments,
            thumbURL: thumbURL
        )
    }

    private func loadEventInfo(from url: URL) -> EventInfo? {
        let eventJSONURL = url.appendingPathComponent("event.json")
        guard let data = try? Data(contentsOf: eventJSONURL),
              let info = try? JSONDecoder().decode(EventInfo.self, from: data)
        else {
            return nil
        }
        return info
    }

    private func groupVideosByTimestamp(_ files: [String], baseURL: URL) -> [Date: [CameraAngle: URL]] {
        var groups: [Date: [CameraAngle: URL]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for file in files {
            let name = (file as NSString).deletingPathExtension
            for angle in CameraAngle.allCases {
                let suffix = "-\(angle.rawValue)"
                if name.hasSuffix(suffix) {
                    let timestampStr = String(name.dropLast(suffix.count))
                    if let date = dateFormatter.date(from: timestampStr) {
                        let fileURL = baseURL.appendingPathComponent(file)
                        groups[date, default: [:]][angle] = fileURL
                    }
                    break
                }
            }
        }

        return groups
    }

    private func getMaxVideoDuration(_ videos: [CameraAngle: URL]) async -> TimeInterval {
        var maxDuration: TimeInterval = 0
        for (_, url) in videos {
            let asset = AVURLAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite {
                    maxDuration = max(maxDuration, seconds)
                }
            } catch {
                continue
            }
        }
        return maxDuration > 0 ? maxDuration : 60.0
    }
}

// MARK: - FSEvents-based directory watcher

private final class DirectoryWatcher: @unchecked Sendable {
    private let paths: [String]
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(paths: [String], onChange: @escaping () -> Void) {
        self.paths = paths
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }

        let context = Unmanaged.passRetained(CallbackBox(onChange)).toOpaque()

        var ctx = FSEventStreamContext(
            version: 0,
            info: context,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsCF = paths as CFArray

        guard let eventStream = FSEventStreamCreate(
            nil,
            DirectoryWatcher.fsEventCallback,
            &ctx,
            pathsCF,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, .main)
        FSEventStreamStart(eventStream)
    }

    func stop() {
        guard let eventStream = stream else { return }
        FSEventStreamStop(eventStream)
        FSEventStreamInvalidate(eventStream)
        FSEventStreamRelease(eventStream)
        stream = nil
    }

    deinit {
        stop()
    }

    private static let fsEventCallback: FSEventStreamCallback = {
        _, clientCallBackInfo, _, _, _, _ in
        guard let info = clientCallBackInfo else { return }
        let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()
        box.handler()
    }

    private final class CallbackBox {
        let handler: () -> Void
        init(_ handler: @escaping () -> Void) {
            self.handler = handler
        }
    }
}
