import SwiftUI

enum RFTab: Hashable, CaseIterable {
    case radar, map, report, intel, rank

    var title: String {
        switch self {
        case .radar: return "Radar"
        case .map: return "Map"
        case .report: return "Report"
        case .intel: return "Intel"
        case .rank: return "Rank"
        }
    }

    var symbol: String {
        switch self {
        case .radar: return "dot.radiowaves.left.and.right"
        case .map: return "map.fill"
        case .report: return "plus.circle.fill"
        case .intel: return "bubble.left.and.bubble.right.fill"
        case .rank: return "person.crop.circle.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selection: RFTab = .radar
    @State private var showReportSheet = false

    var body: some View {
        TabView(selection: $selection) {
            RadarView()
                .tabItem { Label(RFTab.radar.title, systemImage: RFTab.radar.symbol) }
                .tag(RFTab.radar)

            MapSurfaceView()
                .tabItem { Label(RFTab.map.title, systemImage: RFTab.map.symbol) }
                .tag(RFTab.map)

            Color.clear
                .tabItem { Label(RFTab.report.title, systemImage: RFTab.report.symbol) }
                .tag(RFTab.report)

            IntelFeedView()
                .tabItem { Label(RFTab.intel.title, systemImage: RFTab.intel.symbol) }
                .tag(RFTab.intel)

            RankView()
                .tabItem { Label(RFTab.rank.title, systemImage: RFTab.rank.symbol) }
                .tag(RFTab.rank)
        }
        .tint(RFColor.primary)
        .onChange(of: selection) { _, newValue in
            if newValue == .report {
                showReportSheet = true
                // Report is a modal — bounce selection back to where the user was.
                DispatchQueue.main.async { selection = .radar }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportFormView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
