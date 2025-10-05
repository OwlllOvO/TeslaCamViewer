import Foundation
import AVFoundation

// MARK: - Tesla Folder Parser

class TeslaFolderParser {
    static func parse(url: URL) -> ([CameraView], EventInfo?)? {
        let fileManager = FileManager.default
        
        // Read event.json if exists
        let eventURL = url.appendingPathComponent("event.json")
        var eventInfo: EventInfo?
        if fileManager.fileExists(atPath: eventURL.path) {
            if let data = try? Data(contentsOf: eventURL) {
                eventInfo = try? JSONDecoder().decode(EventInfo.self, from: data)
            }
        }
        
        // Get all MP4 files
        guard let files = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        let mp4Files = files.filter { $0.pathExtension.lowercased() == "mp4" }
        
        if mp4Files.isEmpty {
            return nil
        }
        
        // Group files by camera view
        let cameraNames = ["front", "back", "left_pillar", "left_repeater", "right_pillar", "right_repeater"]
        var cameraSegments: [String: [VideoSegment]] = [:]
        
        for file in mp4Files {
            let filename = file.deletingPathExtension().lastPathComponent.lowercased()
            
            // Find which camera this file belongs to
            for cameraName in cameraNames {
                if filename.contains(cameraName) {
                    // Extract timestamp
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    
                    // Try to extract date from filename
                    let pattern = #"(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})"#
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
                       let range = Range(match.range, in: filename) {
                        let dateString = String(filename[range])
                        if let date = dateFormatter.date(from: dateString) {
                            // Get video duration
                            let asset = AVURLAsset(url: file)
                            let duration: CMTime
                            if #available(macOS 13.0, *) {
                                // Use async load for newer macOS
                                // For simplicity, we'll use the old API with fallback
                                duration = asset.duration
                            } else {
                                duration = asset.duration
                            }
                            
                            let segment = VideoSegment(timestamp: date, url: file, duration: duration)
                            cameraSegments[cameraName, default: []].append(segment)
                        }
                    }
                    break
                }
            }
        }
        
        // Sort segments by timestamp for each camera
        for key in cameraSegments.keys {
            cameraSegments[key]?.sort { $0.timestamp < $1.timestamp }
        }
        
        // Create CameraView objects in specific order
        // Layout: Left Pillar, Front, Right Pillar (top row)
        //         Left Repeater, Back, Right Repeater (bottom row)
        let orderedCameraNames = ["left_pillar", "front", "right_pillar", "left_repeater", "back", "right_repeater"]
        let cameras = orderedCameraNames.compactMap { name -> CameraView? in
            guard let segments = cameraSegments[name], !segments.isEmpty else { return nil }
            return CameraView(name: name, segments: segments)
        }
        
        return cameras.isEmpty ? nil : (cameras, eventInfo)
    }
}

