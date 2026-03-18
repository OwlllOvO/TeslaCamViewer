import SwiftUI
import AVFoundation

struct MultiAngleVideoGrid: View {
    @ObservedObject var controller: MultiAnglePlayerController

    private let gridAspectRatio: CGFloat = (1448.0 * 3) / (938.0 * 2)

    var body: some View {
        GeometryReader { geometry in
            gridContent(for: geometry.size)
        }
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
    }
}
