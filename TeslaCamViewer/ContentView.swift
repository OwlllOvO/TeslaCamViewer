import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var scanner = TeslaCamScanner()
    @StateObject private var playerController = MultiAnglePlayerController()
    @State private var selectedEvent: TeslaCamEvent?
    @State private var isDragOver = false
    @State private var showInspector = true
    @State private var keyboardMonitor: Any?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                events: scanner.events,
                selectedEvent: $selectedEvent,
                isLoading: scanner.isLoading
            )
            .frame(minWidth: 220, idealWidth: 280)
        } detail: {
            Group {
                if let event = selectedEvent {
                    VStack(spacing: 0) {
                        ZStack {
                            Color.black
                            MultiAngleVideoGrid(controller: playerController)
                        }
                        .layoutPriority(1)

                        Divider()

                        PlaybackControlsView(controller: playerController, event: event)
                    }
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
            .frame(minWidth: 320, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
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
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
        .onAppear {
            installKeyboardMonitor()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
        .onOpenURL { url in
            openURL(url)
        }
    }

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept if a text field has focus
            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            let shift = event.modifierFlags.contains(.shift)

            switch event.keyCode {
            case 53: // Escape
                if playerController.focusedAngle != nil {
                    playerController.focusedAngle = nil
                    return nil
                }
                return event
            case 49: // Space
                playerController.togglePlayback()
                return nil
            case 123: // Left arrow
                if shift {
                    playerController.skipBackward(10)
                } else {
                    playerController.stepBackward()
                }
                return nil
            case 124: // Right arrow
                if shift {
                    playerController.skipForward(10)
                } else {
                    playerController.stepForward()
                }
                return nil
            default:
                return event
            }
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
