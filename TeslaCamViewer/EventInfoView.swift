import SwiftUI

struct EventInfoView: View {
    let event: TeslaCamEvent

    var body: some View {
        if let info = event.eventInfo {
            HStack(spacing: 16) {
                if let city = info.city {
                    Label(city, systemImage: "building.2")
                }
                if let street = info.street {
                    Label(street, systemImage: "road.lanes")
                }
                if let lat = info.est_lat, let lon = info.est_lon {
                    Label("\(lat), \(lon)", systemImage: "location")
                }
                Label(info.reasonDisplayName, systemImage: "exclamationmark.triangle")

                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
}
