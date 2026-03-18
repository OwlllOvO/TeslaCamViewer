import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var scanner = TeslaCamScanner()
    @StateObject private var playerController = MultiAnglePlayerController()
    @State private var selectedEvent: TeslaCamEvent?
    @State private var isDragOver = false
    @State private var showInspector = true

    var body: some View {
        NavigationSplitView {
            SidebarView(
                events: scanner.events,
                selectedEvent: $selectedEvent,
                isLoading: scanner.isLoading
            )
            .frame(minWidth: 220, idealWidth: 280)
        } detail: {
            if let event = selectedEvent {
                VStack(spacing: 0) {
                    MultiAngleVideoGrid(controller: playerController)
                        .background(.black)
                        .layoutPriority(1)

                    Divider()

                    PlaybackControlsView(controller: playerController)

                    EventInfoView(event: event)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Tesla Dashcam Viewer", systemImage: "car.side")
                } description: {
                    Text("Open a TeslaCam folder or select an event to start viewing.\nYou can also drag a folder here.")
                } actions: {
                    Button("Open Folder…") {
                        openFolder()
                    }
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            if let event = selectedEvent {
                InspectorView(
                    event: event,
                    controller: playerController,
                    onFileSelected: { file in
                        playerController.loadSegment(at: file.segmentIndex)
                    }
                )
                .inspectorColumnWidth(min: 200, ideal: 240, max: 360)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open TeslaCam Folder")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Toggle Inspector")
            }
        }
        .overlay {
            if isDragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, lineWidth: 3)
                    .background(.tint.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: selectedEvent) { _, newEvent in
            if let newEvent {
                playerController.loadEvent(newEvent)
            }
        }
        .onDisappear {
            playerController.cleanup()
        }
        .onKeyPress(.space) {
            playerController.togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            playerController.skipBackward(5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            playerController.skipForward(5)
            return .handled
        }
        .onKeyPress(",") {
            playerController.stepBackward()
            return .handled
        }
        .onKeyPress(".") {
            playerController.stepForward()
            return .handled
        }
        .focusable()
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
        .onOpenURL { url in
            openURL(url)
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a TeslaCam folder (TeslaCam, RecentClips, SavedClips, SentryClips, or an event folder)"

        if panel.runModal() == .OK, let url = panel.url {
            loadFolder(url)
        }
    }

    private func loadFolder(_ url: URL) {
        Task {
            selectedEvent = nil
            playerController.cleanup()
            await scanner.scanDirectory(url)
            if let first = scanner.events.first {
                selectedEvent = first
            }
        }
    }

    private func openURL(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            loadFolder(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            Task { @MainActor in
                openURL(url)
            }
        }
        return true
    }
}
