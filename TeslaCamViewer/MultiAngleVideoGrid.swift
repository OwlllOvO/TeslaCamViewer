import SwiftUI
import AVFoundation

struct MultiAngleVideoGrid: View {
    @ObservedObject var controller: MultiAnglePlayerController

    private let gridAspectRatio: CGFloat = (1448.0 * 3) / (938.0 * 2)
    private let singleAspectRatio: CGFloat = 1448.0 / 938.0

    var body: some View {
        GeometryReader { geometry in
            if let focused = controller.focusedAngle {
                singleAngleView(for: focused, in: geometry.size)
                    .transition(.opacity)
            } else {
                gridContent(for: geometry.size)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controller.focusedAngle)
    }

    private func singleAngleView(for angle: CameraAngle, in size: CGSize) -> some View {
        let viewWidth: CGFloat
        let viewHeight: CGFloat

        if size.width / max(size.height, 1) > singleAspectRatio {
            viewHeight = size.height
            viewWidth = viewHeight * singleAspectRatio
        } else {
            viewWidth = size.width
            viewHeight = viewWidth / singleAspectRatio
        }

        return ZStack {
            if let player = controller.players[angle] {
                PlayerLayerView(player: player)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                            Text(angle.displayName)
                                .font(.title3)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                controller.focusedAngle = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                    Text(angle.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: viewWidth, height: viewHeight)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            controller.focusedAngle = nil
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func gridContent(for size: CGSize) -> some View {
        let gridWidth: CGFloat
        let gridHeight: CGFloat

        if size.width / max(size.height, 1) > gridAspectRatio {
            gridHeight = size.height
            gridWidth = gridHeight * gridAspectRatio
        } else {
            gridWidth = size.width
            gridHeight = gridWidth / gridAspectRatio
        }

        let cellWidth = gridWidth / 3.0
        let cellHeight = gridHeight / 2.0

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(CameraAngle.topRow) { angle in
                    cameraCell(for: angle, width: cellWidth, height: cellHeight)
                }
            }
            HStack(spacing: 0) {
                ForEach(CameraAngle.bottomRow) { angle in
                    cameraCell(for: angle, width: cellWidth, height: cellHeight)
                }
            }
        }
        .frame(width: gridWidth, height: gridHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func cameraCell(for angle: CameraAngle, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let player = controller.players[angle] {
                PlayerLayerView(player: player)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "video.slash")
                                .font(.title3)
                            Text(angle.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if controller.players[angle] != nil {
                controller.focusedAngle = angle
            }
        }
        .onHover { hovering in
            if hovering && controller.players[angle] != nil {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
