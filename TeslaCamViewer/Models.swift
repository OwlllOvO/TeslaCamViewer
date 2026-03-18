import Foundation

enum CameraAngle: String, CaseIterable, Identifiable {
    case front
    case back
    case leftPillar = "left_pillar"
    case leftRepeater = "left_repeater"
    case rightPillar = "right_pillar"
    case rightRepeater = "right_repeater"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .leftPillar: return "Left Pillar"
        case .leftRepeater: return "Left Repeater"
        case .rightPillar: return "Right Pillar"
        case .rightRepeater: return "Right Repeater"
        }
    }

    static var topRow: [CameraAngle] { [.leftPillar, .front, .rightPillar] }
    static var bottomRow: [CameraAngle] { [.leftRepeater, .back, .rightRepeater] }
}

struct EventInfo: Codable, Equatable {
    let timestamp: String?
    let city: String?
    let street: String?
    let est_lat: String?
    let est_lon: String?
    let reason: String?
    let camera: String?

    var eventDate: Date? {
        guard let timestamp else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: timestamp)
    }

    var reasonDisplayName: String {
        guard let reason else { return "Unknown" }
        return reason
            .replacingOccurrences(of: "user_interaction_", with: "")
            .replacingOccurrences(of: "dashcam_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct VideoFile: Identifiable, Hashable {
    let id: String
    let url: URL
    let angle: CameraAngle
    let segmentIndex: Int

    var fileName: String { url.lastPathComponent }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        lhs.id == rhs.id
    }
}

struct ClipSegment: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let videos: [CameraAngle: URL]
    let duration: TimeInterval

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var sortedFileNames: [String] {
        videos.values.map(\.lastPathComponent).sorted()
    }

    static func == (lhs: ClipSegment, rhs: ClipSegment) -> Bool {
        lhs.id == rhs.id
    }
}

struct TeslaCamEvent: Identifiable, Equatable {
    let id = UUID()
    let folderURL: URL
    let eventInfo: EventInfo?
    let segments: [ClipSegment]
    let thumbURL: URL?
    var sourceFolder: String?

    var displayName: String {
        let name = folderURL.lastPathComponent
        if let eventInfo, let city = eventInfo.city, let street = eventInfo.street {
            return "\(name) - \(city) \(street)"
        }
        return name
    }

    var eventTimestamp: Date? {
        eventInfo?.eventDate
    }

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var startTime: Date? {
        segments.first?.timestamp
    }

    var allVideoFiles: [VideoFile] {
        var files: [VideoFile] = []
        for (segIdx, segment) in segments.enumerated() {
            for angle in CameraAngle.allCases {
                if let url = segment.videos[angle] {
                    files.append(VideoFile(
                        id: "\(segIdx)-\(angle.rawValue)",
                        url: url,
                        angle: angle,
                        segmentIndex: segIdx
                    ))
                }
            }
        }
        return files
    }

    func videoFiles(forSegment index: Int) -> Set<String> {
        guard segments.indices.contains(index) else { return [] }
        return Set(CameraAngle.allCases.compactMap { angle in
            segments[index].videos[angle] != nil ? "\(index)-\(angle.rawValue)" : nil
        })
    }

    static func == (lhs: TeslaCamEvent, rhs: TeslaCamEvent) -> Bool {
        lhs.id == rhs.id
    }
}

enum FolderType {
    case teslaCam
    case recentClips
    case savedClips
    case sentryClips
    case singleEvent
}
