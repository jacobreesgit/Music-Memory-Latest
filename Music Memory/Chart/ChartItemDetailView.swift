import SwiftUI
import Charts

// MARK: - Chart Item Detail View
struct ChartItemDetailView: View {
    let chartItem: ChartItem
    let dateRange: DateRangeFilter
    
    @StateObject private var detailManager = ChartDetailManager()
    @State private var historicalData: [ChartHistoryPoint] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with artwork and basic info
                    headerView
                    
                    // Current stats
                    currentStatsView
                    
                    // Chart history
                    if !historicalData.isEmpty {
                        chartHistoryView
                    }
                    
                    // Detailed analytics
                    detailedAnalyticsView
                    
                    // Recent plays (for songs)
                    if chartItem.entityType == .song {
                        recentPlaysView
                    }
                }
                .padding()
            }
            .navigationTitle("Chart Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: generateShareText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            loadDetailData()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 16) {
            // Large artwork
            AsyncImage(url: chartItem.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: iconForEntityType)
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 8) {
                // Position and movement
                HStack(spacing: 8) {
                    Text("#\(chartItem.position)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    MovementBadge(movement: chartItem.movement)
                }
                
                // Title and subtitle
                Text(chartItem.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(chartItem.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Entity type badge
                Text(chartItem.entityType.displayName.dropLast()) // Remove 's'
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Current Stats View
    private var currentStatsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Period Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(dateRange.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Total Plays",
                    value: chartItem.formattedPlayCount,
                    subtitle: "times played",
                    icon: "play.circle.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Listen Time",
                    value: chartItem.formattedDuration,
                    subtitle: "total duration",
                    icon: "clock.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Completion",
                    value: "\(Int(chartItem.averageCompletion * 100))%",
                    subtitle: "average completion",
                    icon: "chart.bar.fill",
                    color: .orange
                )
                
                if let uniqueSongs = chartItem.uniqueSongsPlayed {
                    StatCard(
                        title: chartItem.entityType == .artist ? "Songs" : "Tracks",
                        value: "\(uniqueSongs)",
                        subtitle: "unique songs",
                        icon: "music.note.list",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Chart History View
    private var chartHistoryView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Chart History")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Last 12 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if #available(iOS 16.0, *) {
                Chart(historicalData) { point in
                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("Position", point.position)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Week", point.date),
                        y: .value("Position", point.position)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            } else {
                // Fallback for iOS 15
                Text("Chart history requires iOS 16+")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Detailed Analytics View
    private var detailedAnalyticsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Detailed Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                AnalyticsRow(
                    title: "Peak Position",
                    value: "#\(detailManager.peakPosition)",
                    subtitle: "highest chart position"
                )
                
                AnalyticsRow(
                    title: "Weeks on Chart",
                    value: "\(detailManager.weeksOnChart)",
                    subtitle: "total weeks charted"
                )
                
                AnalyticsRow(
                    title: "Chart Debut",
                    value: formatDate(detailManager.chartDebut),
                    subtitle: "first appearance"
                )
                
                if chartItem.entityType == .song {
                    AnalyticsRow(
                        title: "Skip Rate",
                        value: "\(Int((1 - chartItem.averageCompletion) * 100))%",
                        subtitle: "songs not completed"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Plays View
    private var recentPlaysView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Plays")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Last 10 plays")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                ProgressView()
                    .frame(height: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(detailManager.recentPlays, id: \.timestamp) { play in
                        RecentPlayRow(play: play)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Views
    private var iconForEntityType: String {
        switch chartItem.entityType {
        case .song: return "music.note"
        case .album: return "opticaldisc"
        case .artist: return "person.fill"
        }
    }
    
    // MARK: - Actions
    private func loadDetailData() {
        Task {
            await detailManager.loadDetailData(for: chartItem, in: dateRange)
            
            await MainActor.run {
                self.historicalData = detailManager.chartHistory
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func generateShareText() -> String {
        let entityType = chartItem.entityType.displayName.dropLast()
        return """
        🎵 My #\(chartItem.position) \(entityType): \(chartItem.title) by \(chartItem.subtitle)
        
        📊 \(chartItem.formattedPlayCount) plays • \(chartItem.formattedDuration) listening time
        📈 \(chartItem.movement.displayString) from last period
        
        #MusicMemory #PersonalHot100
        """
    }
}

// MARK: - Movement Badge
struct MovementBadge: View {
    let movement: ChartItemMovement
    
    var body: some View {
        HStack(spacing: 2) {
            if case .up(let positions) = movement {
                Image(systemName: "arrow.up")
                    .font(.caption)
            } else if case .down(let positions) = movement {
                Image(systemName: "arrow.down")
                    .font(.caption)
            }
            
            Text(movement.displayString)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(movement.color)
        )
    }
}

// MARK: - Enhanced Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Analytics Row
struct AnalyticsRow: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Play Row
struct RecentPlayRow: View {
    let play: RecentPlayInfo
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatPlayTime(play.timestamp))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formatDate(play.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(play.completionPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(play.completionPercentage >= 0.8 ? .green : .primary)
                
                Text(formatDuration(play.playDuration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func formatPlayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Chart Detail Manager
class ChartDetailManager: ObservableObject {
    @Published var chartHistory: [ChartHistoryPoint] = []
    @Published var recentPlays: [RecentPlayInfo] = []
    @Published var peakPosition: Int = 0
    @Published var weeksOnChart: Int = 0
    @Published var chartDebut: Date?
    
    private let persistenceController = PersistenceController.shared
    
    func loadDetailData(for item: ChartItem, in dateRange: DateRangeFilter) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadChartHistory(for: item)
            }
            
            group.addTask {
                await self.loadRecentPlays(for: item, in: dateRange)
            }
            
            group.addTask {
                await self.loadAnalytics(for: item)
            }
        }
    }
    
    private func loadChartHistory(for item: ChartItem) async {
        // Generate mock chart history data for now
        // In a real implementation, this would query ChartSnapshot entities
        let calendar = Calendar.current
        var history: [ChartHistoryPoint] = []
        
        for week in 0..<12 {
            if let date = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) {
                // Simulate chart position fluctuation
                let basePosition = item.position
                let variation = Int.random(in: -5...5)
                let position = max(1, min(100, basePosition + variation))
                
                history.append(ChartHistoryPoint(date: date, position: position))
            }
        }
        
        await MainActor.run {
            self.chartHistory = history.reversed()
            self.peakPosition = history.map { $0.position }.min() ?? item.position
            self.weeksOnChart = history.count
            self.chartDebut = history.first?.date
        }
    }
    
    private func loadRecentPlays(for item: ChartItem, in dateRange: DateRangeFilter) async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            let fetchRequest: NSFetchRequest<RecentPlay> = RecentPlay.fetchRequest()
            
            let predicate: NSPredicate
            switch item.entityType {
            case .song:
                predicate = NSPredicate(format: "songID == %@ AND timestamp >= %@ AND timestamp <= %@",
                                      item.entityID,
                                      dateRange.startDate as NSDate,
                                      dateRange.endDate as NSDate)
            case .album:
                predicate = NSPredicate(format: "albumID == %@ AND timestamp >= %@ AND timestamp <= %@",
                                      item.entityID,
                                      dateRange.startDate as NSDate,
                                      dateRange.endDate as NSDate)
            case .artist:
                predicate = NSPredicate(format: "artistID == %@ AND timestamp >= %@ AND timestamp <= %@",
                                      item.entityID,
                                      dateRange.startDate as NSDate,
                                      dateRange.endDate as NSDate)
            }
            
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecentPlay.timestamp, ascending: false)]
            fetchRequest.fetchLimit = 10
            
            do {
                let plays = try context.fetch(fetchRequest)
                let playInfos = plays.map { play in
                    RecentPlayInfo(
                        timestamp: play.timestamp,
                        playDuration: play.playDuration,
                        completionPercentage: play.completionPercentage
                    )
                }
                
                await MainActor.run {
                    self.recentPlays = playInfos
                }
            } catch {
                print("Error fetching recent plays: \(error)")
            }
        }
    }
    
    private func loadAnalytics(for item: ChartItem) async {
        // Load additional analytics data
        // This could include trend analysis, comparison with other periods, etc.
        await MainActor.run {
            // Set default values for now
            if self.peakPosition == 0 {
                self.peakPosition = item.position
            }
            if self.weeksOnChart == 0 {
                self.weeksOnChart = 1
            }
            if self.chartDebut == nil {
                self.chartDebut = Calendar.current.date(byAdding: .day, value: -7, to: Date())
            }
        }
    }
}

// MARK: - Supporting Models
struct ChartHistoryPoint {
    let date: Date
    let position: Int
}

struct RecentPlayInfo {
    let timestamp: Date
    let playDuration: TimeInterval
    let completionPercentage: Double
}
