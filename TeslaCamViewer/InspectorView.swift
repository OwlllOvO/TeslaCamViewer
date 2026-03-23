import SwiftUI

struct InspectorView: View {
    let event: TeslaCamEvent
    @ObservedObject var controller: MultiAnglePlayerController
    let onFileSelected: (VideoFile) -> Void

    @State private var selection: Set<String> = []

    private var allFiles: [VideoFile] {
        event.allVideoFiles
    }

    private struct SegmentGroup: Identifiable {
        let id: Int
        let segment: ClipSegment
        let files: [VideoFile]
    }

    private var segmentGroups: [SegmentGroup] {
        event.segments.enumerated().map { index, segment in
            let files = CameraAngle.allCases.compactMap { angle -> VideoFile? in
                guard segment.videos[angle] != nil else { return nil }
                return VideoFile(
                    id: "\(index)-\(angle.rawValue)",
                    url: segment.videos[angle]!,
                    angle: angle,
                    segmentIndex: index
                )
            }
            return SegmentGroup(id: index, segment: segment, files: files)
        }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(segmentGroups) { group in
                Section(group.segment.displayTime) {
                    ForEach(group.files) { file in
                        Label(file.fileName, systemImage: "film")
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .tag(file.id)
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(event.folderURL.lastPathComponent)
        .onChange(of: controller.currentSegmentIndex) { _, newIndex in
            selection = event.videoFiles(forSegment: newIndex)
        }
        .onChange(of: selection) { oldValue, newValue in
            guard newValue != event.videoFiles(forSegment: controller.currentSegmentIndex) else {
                return
            }
            if let clickedID = newValue.subtracting(oldValue).first,
               let file = allFiles.first(where: { $0.id == clickedID }) {
                onFileSelected(file)
            }
        }
        .onAppear {
            selection = event.videoFiles(forSegment: controller.currentSegmentIndex)
        }
    }
}
