import SwiftUI

// MARK: - Main Charts View
struct ChartsView: View {
    @StateObject private var chartEngine = ChartCalculationEngine()
    @StateObject private var updateManager = ChartUpdateManager()
    
    @State private var selectedEntityType: EntityType = .song
    @State private var selectedDateRange = DateRangeFilter.presetRanges[1] // Last 30 Days
    @State private var chartItems: [ChartItem] = []
    @State private var isLoading = false
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                chartHeaderView
                
                // Chart content
                if isLoading {
                    loadingView
                } else if chartItems.isEmpty {
                    emptyStateView
                } else {
                    chartListView
                }
            }
            .navigationTitle("Your Hot 100")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        // TODO: Export functionality
                    }
                    .disabled(chartItems.isEmpty)
                }
            }
        }
        .onAppear {
            loadChart()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chartsNeedUpdate)) { _ in
            if updateManager.needsUpdate.contains(selectedEntityType) {
                loadChart()
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationView {
                CustomDateRangePicker(selectedRange: $selectedDateRange)
                    .navigationTitle("Select Period")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDatePicker = false
                                loadChart()
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Chart Header
    private var chartHeaderView: some View {
        VStack(spacing: 16) {
            // Entity type selector
            entityTypeSelector
            
            // Date range selector
            dateRangeSelector
            
            // Chart info
            if !chartItems.isEmpty {
                chartInfoView
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var entityTypeSelector: some View {
        HStack(spacing: 0) {
            ForEach(EntityType.allCases, id: \.self) { entityType in
                Button(action: {
                    selectedEntityType = entityType
                    loadChart()
                }) {
                    Text(entityType.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedEntityType == entityType ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedEntityType == entityType ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
    
    private var dateRangeSelector: some View {
        Button(action: {
            showingDatePicker = true
        }) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDateRange.displayName)
                        .font(.system(size: 15, weight: .medium))
                    
                    Text(queryStrategyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var queryStrategyDescription: String {
        switch selectedDateRange.queryStrategy {
        case .useRecentPlays:
            return "Maximum detail tracking"
        case .useDailyAggregates:
            return "Daily summary data"
        case .useWeeklyAggregates:
            return "Weekly summary data"
        }
    }
    
    private var chartInfoView: some View {
        HStack {
            Text("\(chartItems.count) \(selectedEntityType.displayName.lowercased())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Updated \(formatLastUpdate())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Chart Content Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Calculating your Hot 100...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No \(selectedEntityType.displayName) Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start listening to music to see your personalized Hot 100 chart")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var chartListView: some View {
        List {
            ForEach(Array(chartItems.enumerated()), id: \.element.id) { index, item in
                ChartItemRow(item: item, rank: index + 1)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Actions
    private func loadChart() {
        isLoading = true
        
        chartEngine.calculateHot100(
            entityType: selectedEntityType,
            dateRange: selectedDateRange
        ) { items in
            withAnimation(.easeInOut(duration: 0.3)) {
                self.chartItems = items
                self.isLoading = false
            }
        }
    }
    
    private func formatLastUpdate() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Chart Item Row
struct ChartItemRow: View {
    let item: ChartItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank and movement
            rankAndMovementView
            
            // Artwork
            AsyncImage(url: item.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Additional info based on entity type
                additionalInfoView
            }
            
            Spacer()
            
            // Stats
            statsView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var rankAndMovementView: some View {
        VStack(spacing: 4) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 32)
            
            // Movement indicator
            Text(item.movement.displayString)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(item.movement.color)
                .frame(width: 32)
        }
    }
    
    @ViewBuilder
    private var additionalInfoView: some View {
        switch item.entityType {
        case .song:
            Text("\(Int(item.averageCompletion * 100))% avg completion")
                .font(.caption)
                .foregroundColor(.secondary)
                
        case .album:
            if let uniqueSongs = item.uniqueSongsPlayed {
                Text("\(uniqueSongs) songs played")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .artist:
            if let uniqueSongs = item.uniqueSongsPlayed, let uniqueAlbums = item.uniqueAlbumsPlayed {
                Text("\(uniqueSongs) songs • \(uniqueAlbums) albums")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statsView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(item.formattedPlayCount)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("plays")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(item.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Chart Update Manager
class ChartUpdateManager: ObservableObject {
    @Published var needsUpdate: Set<EntityType> = []
    private let updateThreshold = 5 // Update after 5 new plays
    private var playsSinceLastUpdate = 0
    
    init() {
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .songCompletionLogged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleNewPlay()
        }
    }
    
    func handleNewPlay() {
        playsSinceLastUpdate += 1
        
        if playsSinceLastUpdate >= updateThreshold {
            triggerChartUpdates()
            playsSinceLastUpdate = 0
        }
    }
    
    private func triggerChartUpdates() {
        needsUpdate = Set(EntityType.allCases)
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .chartsNeedUpdate,
            object: nil
        )
        
        // Clear update flags after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.needsUpdate.removeAll()
        }
    }
}

// MARK: - Chart Filtering and Sorting
enum ChartSortOption: String, CaseIterable {
    case playCount = "Play Count"
    case totalDuration = "Total Duration"
    case averageCompletion = "Completion Rate"
    case alphabetical = "Alphabetical"
    
    var systemImage: String {
        switch self {
        case .playCount: return "number"
        case .totalDuration: return "clock"
        case .averageCompletion: return "percent"
        case .alphabetical: return "textformat.abc"
        }
    }
}

enum ChartFilterOption {
    case all
    case minimumPlays(Int)
    case minimumCompletion(Double)
    case minimumDuration(TimeInterval)
}

// MARK: - Export Manager
class ChartExportManager {
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            }
        }
    }
    
    func exportChart(
        _ chart: [ChartItem],
        entityType: EntityType,
        dateRange: DateRangeFilter,
        format: ExportFormat
    ) -> Data? {
        
        switch format {
        case .csv:
            return exportToCSV(chart, entityType: entityType, dateRange: dateRange)
        case .json:
            return exportToJSON(chart, entityType: entityType, dateRange: dateRange)
        }
    }
    
    private func exportToCSV(_ chart: [ChartItem], entityType: EntityType, dateRange: DateRangeFilter) -> Data? {
        var csvContent = generateCSVHeader(for: entityType)
        
        for item in chart {
            let row = [
                "\(item.position)",
                "\"" + item.title.replacingOccurrences(of: "\"", with: "\"\"") + "\"",
                "\"" + item.subtitle.replacingOccurrences(of: "\"", with: "\"\"") + "\"",
                "\(item.playCount)",
                item.formattedDuration,
                String(format: "%.1f%%", item.averageCompletion * 100),
                item.movement.displayString
            ].joined(separator: ",")
            
            csvContent += "\n" + row
        }
        
        return csvContent.data(using: .utf8)
    }
    
    private func exportToJSON(_ chart: [ChartItem], entityType: EntityType, dateRange: DateRangeFilter) -> Data? {
        let exportData: [String: Any] = [
            "entityType": entityType.rawValue,
            "dateRange": [
                "displayName": dateRange.displayName,
                "startDate": ISO8601DateFormatter().string(from: dateRange.startDate),
                "endDate": ISO8601DateFormatter().string(from: dateRange.endDate)
            ],
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "chart": chart.map { item in
                [
                    "position": item.position,
                    "entityID": item.entityID,
                    "title": item.title,
                    "subtitle": item.subtitle,
                    "playCount": item.playCount,
                    "totalDuration": item.totalDuration,
                    "averageCompletion": item.averageCompletion,
                    "movement": item.movement.displayString
                ]
            }
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            print("Error serializing JSON: \(error)")
            return nil
        }
    }
    
    private func generateCSVHeader(for entityType: EntityType) -> String {
        return "Position,Title,\(entityType == .artist ? "Artist" : "Artist/Album"),Play Count,Total Duration,Avg Completion,Movement"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chartsNeedUpdate = Notification.Name("chartsNeedUpdate")
}
