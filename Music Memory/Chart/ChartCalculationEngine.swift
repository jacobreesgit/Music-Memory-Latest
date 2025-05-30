import Foundation
import CoreData
import SwiftUI

// MARK: - Date Range Filter System
struct DateRangeFilter {
    let startDate: Date
    let endDate: Date
    let displayName: String
    let queryStrategy: QueryStrategy
    
    static let presetRanges: [DateRangeFilter] = [
        DateRangeFilter(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            endDate: Date(),
            displayName: "Last 7 Days",
            queryStrategy: .useRecentPlays
        ),
        DateRangeFilter(
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            endDate: Date(),
            displayName: "Last 30 Days",
            queryStrategy: .useDailyAggregates
        ),
        DateRangeFilter(
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
            endDate: Date(),
            displayName: "Last 3 Months",
            queryStrategy: .useDailyAggregates
        ),
        DateRangeFilter(
            startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            endDate: Date(),
            displayName: "Last 6 Months",
            queryStrategy: .useDailyAggregates
        ),
        DateRangeFilter(
            startDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
            endDate: Date(),
            displayName: "This Year",
            queryStrategy: .useWeeklyAggregates
        )
    ]
    
    static func determineQueryStrategy(start: Date, end: Date) -> QueryStrategy {
        let daysDifference = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        
        switch daysDifference {
        case 0...30:
            return .useRecentPlays
        case 31...365:
            return .useDailyAggregates
        default:
            return .useWeeklyAggregates
        }
    }
    
    static func formatCustomRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(start, equalTo: end, toGranularity: .year) {
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

// MARK: - Entity Types
enum EntityType: String, CaseIterable {
    case song = "song"
    case album = "album"
    case artist = "artist"
    
    var displayName: String {
        switch self {
        case .song: return "Songs"
        case .album: return "Albums"
        case .artist: return "Artists"
        }
    }
}

// MARK: - Chart Movement (Chart-specific version)
enum ChartItemMovement: Equatable {
    case new                    // First time on chart
    case reentry               // Returning after absence
    case up(Int)               // Moved up X positions
    case down(Int)             // Moved down X positions
    case steady                // Same position
    
    var displayString: String {
        switch self {
        case .new: return "NEW"
        case .reentry: return "RE"
        case .up(let positions): return "↑\(positions)"
        case .down(let positions): return "↓\(positions)"
        case .steady: return "—"
        }
    }
    
    var color: Color {
        switch self {
        case .new, .reentry, .up: return .green
        case .down: return .red
        case .steady: return .secondary
        }
    }
}

// MARK: - Chart Item Model
struct ChartItem: Identifiable, Equatable {
    let id = UUID()
    let entityID: String
    let entityType: EntityType
    var position: Int = 0
    let title: String
    let subtitle: String
    let playCount: Int
    let totalDuration: TimeInterval
    let averageCompletion: Double
    let artworkURL: URL?
    var movement: ChartItemMovement = .new
    
    // Optional properties for different entity types
    let uniqueSongsPlayed: Int?
    let uniqueAlbumsPlayed: Int?
    
    // Formatted display properties
    var formattedPlayCount: String {
        if playCount < 1000 {
            return "\(playCount)"
        } else if playCount < 1000000 {
            return String(format: "%.1fK", Double(playCount) / 1000.0)
        } else {
            return String(format: "%.1fM", Double(playCount) / 1000000.0)
        }
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    static func == (lhs: ChartItem, rhs: ChartItem) -> Bool {
        return lhs.entityID == rhs.entityID && lhs.entityType == rhs.entityType
    }
}

// MARK: - Chart Calculation Engine
class ChartCalculationEngine: ObservableObject {
    private let persistenceController: PersistenceController
    private let cacheManager = ChartCacheManager()
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    func calculateHot100(
        entityType: EntityType,
        dateRange: DateRangeFilter,
        completion: @escaping ([ChartItem]) -> Void
    ) {
        // Check cache first
        if let cachedChart = cacheManager.getCachedChart(entityType: entityType, dateRange: dateRange) {
            completion(cachedChart)
            return
        }
        
        Task {
            let chartItems = await performCalculation(entityType: entityType, dateRange: dateRange)
            
            // Cache the results
            cacheManager.cacheChart(chartItems, entityType: entityType, dateRange: dateRange)
            
            await MainActor.run {
                completion(chartItems)
            }
        }
    }
    
    private func performCalculation(
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) async -> [ChartItem] {
        
        switch dateRange.queryStrategy {
        case .useRecentPlays:
            return await calculateFromRecentPlays(entityType: entityType, dateRange: dateRange)
        case .useDailyAggregates:
            return await calculateFromDailyAggregates(entityType: entityType, dateRange: dateRange)
        case .useWeeklyAggregates:
            return await calculateFromWeeklyAggregates(entityType: entityType, dateRange: dateRange)
        }
    }
    
    // MARK: - Recent Plays Calculation
    private func calculateFromRecentPlays(
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) async -> [ChartItem] {
        
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<RecentPlay> = RecentPlay.fetchRequest()
        
        let predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                   dateRange.startDate as NSDate,
                                   dateRange.endDate as NSDate)
        fetchRequest.predicate = predicate
        
        do {
            let plays = try context.fetch(fetchRequest)
            
            switch entityType {
            case .song:
                return calculateSongChart(from: plays)
            case .album:
                return calculateAlbumChart(from: plays)
            case .artist:
                return calculateArtistChart(from: plays)
            }
        } catch {
            print("Error fetching recent plays: \(error)")
            return []
        }
    }
    
    // MARK: - Song Chart Calculation
    private func calculateSongChart(from plays: [RecentPlay]) -> [ChartItem] {
        // Group plays by songID
        let groupedPlays = Dictionary(grouping: plays, by: { $0.songID })
        
        // Calculate play counts and create chart items
        let chartItems = groupedPlays.compactMap { (songID, plays) -> ChartItem? in
            guard let metadata = getSongMetadata(for: songID) else { return nil }
            
            let playCount = plays.count
            let totalDuration = plays.reduce(0) { $0 + $1.playDuration }
            let averageCompletion = plays.map { $0.completionPercentage }.reduce(0, +) / Double(plays.count)
            
            return ChartItem(
                entityID: songID,
                entityType: .song,
                title: metadata.title,
                subtitle: metadata.artist,
                playCount: playCount,
                totalDuration: totalDuration,
                averageCompletion: averageCompletion,
                artworkURL: metadata.artworkURL.flatMap { URL(string: $0) },
                uniqueSongsPlayed: nil,
                uniqueAlbumsPlayed: nil
            )
        }
        
        // Sort by play count and assign positions
        let sortedItems = chartItems.sorted { $0.playCount > $1.playCount }
        return assignPositions(to: sortedItems)
    }
    
    // MARK: - Album Chart Calculation
    private func calculateAlbumChart(from plays: [RecentPlay]) -> [ChartItem] {
        // Group plays by albumID (aggregate all tracks in album)
        let groupedPlays = Dictionary(grouping: plays, by: { $0.albumID })
        
        let chartItems = groupedPlays.compactMap { (albumID, plays) -> ChartItem? in
            guard let metadata = getAlbumMetadata(for: albumID) else { return nil }
            
            let totalPlays = plays.count
            let totalDuration = plays.reduce(0) { $0 + $1.playDuration }
            let uniqueSongs = Set(plays.map { $0.songID }).count
            let averageCompletion = plays.map { $0.completionPercentage }.reduce(0, +) / Double(plays.count)
            
            return ChartItem(
                entityID: albumID,
                entityType: .album,
                title: metadata.title,
                subtitle: metadata.artist,
                playCount: totalPlays,
                totalDuration: totalDuration,
                averageCompletion: averageCompletion,
                artworkURL: metadata.artworkURL.flatMap { URL(string: $0) },
                uniqueSongsPlayed: uniqueSongs,
                uniqueAlbumsPlayed: nil
            )
        }
        
        let sortedItems = chartItems.sorted { $0.playCount > $1.playCount }
        return assignPositions(to: sortedItems)
    }
    
    // MARK: - Artist Chart Calculation
    private func calculateArtistChart(from plays: [RecentPlay]) -> [ChartItem] {
        // Group plays by artistID (aggregate all songs by artist)
        let groupedPlays = Dictionary(grouping: plays, by: { $0.artistID })
        
        let chartItems = groupedPlays.compactMap { (artistID, plays) -> ChartItem? in
            guard let metadata = getArtistMetadata(for: artistID) else { return nil }
            
            let totalPlays = plays.count
            let totalDuration = plays.reduce(0) { $0 + $1.playDuration }
            let uniqueSongs = Set(plays.map { $0.songID }).count
            let uniqueAlbums = Set(plays.map { $0.albumID }).count
            let averageCompletion = plays.map { $0.completionPercentage }.reduce(0, +) / Double(plays.count)
            
            let subtitle = formatArtistSubtitle(uniqueSongs: uniqueSongs, uniqueAlbums: uniqueAlbums)
            
            return ChartItem(
                entityID: artistID,
                entityType: .artist,
                title: metadata.name,
                subtitle: subtitle,
                playCount: totalPlays,
                totalDuration: totalDuration,
                averageCompletion: averageCompletion,
                artworkURL: metadata.imageURL.flatMap { URL(string: $0) },
                uniqueSongsPlayed: uniqueSongs,
                uniqueAlbumsPlayed: uniqueAlbums
            )
        }
        
        let sortedItems = chartItems.sorted { $0.playCount > $1.playCount }
        return assignPositions(to: sortedItems)
    }
    
    // MARK: - Daily Aggregates Calculation
    private func calculateFromDailyAggregates(
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) async -> [ChartItem] {
        
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<DailyAggregate> = DailyAggregate.fetchRequest()
        
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND entityType == %@",
                                   dateRange.startDate as NSDate,
                                   dateRange.endDate as NSDate,
                                   entityType.rawValue)
        fetchRequest.predicate = predicate
        
        do {
            let aggregates = try context.fetch(fetchRequest)
            return calculateFromAggregates(aggregates, entityType: entityType)
        } catch {
            print("Error fetching daily aggregates: \(error)")
            return []
        }
    }
    
    // MARK: - Weekly Aggregates Calculation (placeholder for now)
    private func calculateFromWeeklyAggregates(
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) async -> [ChartItem] {
        // For now, use daily aggregates approach
        // In a full implementation, you'd have weekly aggregate tables
        return await calculateFromDailyAggregates(entityType: entityType, dateRange: dateRange)
    }
    
    // MARK: - Aggregate Processing
    private func calculateFromAggregates(_ aggregates: [DailyAggregate], entityType: EntityType) -> [ChartItem] {
        // Group aggregates by entityID and sum the values
        let groupedAggregates = Dictionary(grouping: aggregates, by: { $0.entityID })
        
        let chartItems = groupedAggregates.compactMap { (entityID, aggregates) -> ChartItem? in
            let totalPlays = aggregates.reduce(0) { $0 + Int($1.playCount) }
            let totalDuration = aggregates.reduce(0) { $0 + $1.totalDuration }
            let averageCompletion = aggregates.map { $0.averageCompletion }.reduce(0, +) / Double(aggregates.count)
            
            switch entityType {
            case .song:
                guard let metadata = getSongMetadata(for: entityID) else { return nil }
                return ChartItem(
                    entityID: entityID,
                    entityType: .song,
                    title: metadata.title,
                    subtitle: metadata.artist,
                    playCount: totalPlays,
                    totalDuration: totalDuration,
                    averageCompletion: averageCompletion,
                    artworkURL: metadata.artworkURL.flatMap { URL(string: $0) },
                    uniqueSongsPlayed: nil,
                    uniqueAlbumsPlayed: nil
                )
                
            case .album:
                guard let metadata = getAlbumMetadata(for: entityID) else { return nil }
                return ChartItem(
                    entityID: entityID,
                    entityType: .album,
                    title: metadata.title,
                    subtitle: metadata.artist,
                    playCount: totalPlays,
                    totalDuration: totalDuration,
                    averageCompletion: averageCompletion,
                    artworkURL: metadata.artworkURL.flatMap { URL(string: $0) },
                    uniqueSongsPlayed: nil, // Would need additional calculation
                    uniqueAlbumsPlayed: nil
                )
                
            case .artist:
                guard let metadata = getArtistMetadata(for: entityID) else { return nil }
                return ChartItem(
                    entityID: entityID,
                    entityType: .artist,
                    title: metadata.name,
                    subtitle: "Artist",
                    playCount: totalPlays,
                    totalDuration: totalDuration,
                    averageCompletion: averageCompletion,
                    artworkURL: metadata.imageURL.flatMap { URL(string: $0) },
                    uniqueSongsPlayed: nil, // Would need additional calculation
                    uniqueAlbumsPlayed: nil
                )
            }
        }
        
        let sortedItems = chartItems.sorted { $0.playCount > $1.playCount }
        return assignPositions(to: sortedItems)
    }
    
    // MARK: - Helper Methods
    private func assignPositions(to items: [ChartItem]) -> [ChartItem] {
        return items.enumerated().map { index, item in
            var updatedItem = item
            updatedItem.position = index + 1
            return updatedItem
        }
    }
    
    private func formatArtistSubtitle(uniqueSongs: Int, uniqueAlbums: Int) -> String {
        if uniqueAlbums > 1 {
            return "\(uniqueSongs) songs • \(uniqueAlbums) albums"
        } else {
            return "\(uniqueSongs) songs"
        }
    }
    
    // MARK: - Metadata Fetching
    private func getSongMetadata(for songID: String) -> SongMetadata? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<SongMetadata> = SongMetadata.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "songID == %@", songID)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching song metadata: \(error)")
            return nil
        }
    }
    
    private func getAlbumMetadata(for albumID: String) -> AlbumMetadata? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AlbumMetadata> = AlbumMetadata.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "albumID == %@", albumID)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching album metadata: \(error)")
            return nil
        }
    }
    
    private func getArtistMetadata(for artistID: String) -> ArtistMetadata? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ArtistMetadata> = ArtistMetadata.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "artistID == %@", artistID)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching artist metadata: \(error)")
            return nil
        }
    }
}

// MARK: - Chart Movement Tracker
class ChartMovementTracker {
    
    func calculateMovement(
        currentChart: [ChartItem],
        previousChart: [ChartItem]?,
        entityType: EntityType
    ) -> [ChartItem] {
        
        guard let previousChart = previousChart else {
            // First time calculating - all items are new
            return currentChart.map { item in
                var updatedItem = item
                updatedItem.movement = .new
                return updatedItem
            }
        }
        
        let previousPositions = Dictionary(
            uniqueKeysWithValues: previousChart.map { ($0.entityID, $0.position) }
        )
        
        return currentChart.map { item in
            var updatedItem = item
            
            if let previousPosition = previousPositions[item.entityID] {
                let positionChange = previousPosition - item.position
                
                switch positionChange {
                case 0:
                    updatedItem.movement = .steady
                case let change where change > 0:
                    updatedItem.movement = .up(change)
                case let change where change < 0:
                    updatedItem.movement = .down(abs(change))
                default:
                    updatedItem.movement = .steady
                }
            } else {
                // Not on previous chart - could be new or re-entry
                updatedItem.movement = determineNewVsReentry(item.entityID, entityType: entityType)
            }
            
            return updatedItem
        }
    }
    
    private func determineNewVsReentry(_ entityID: String, entityType: EntityType) -> ChartItemMovement {
        // Check if this entity has been on charts before
        // For now, default to .new, but this could be enhanced with historical chart data
        return .new
    }
}

// MARK: - Chart Cache Manager
class ChartCacheManager {
    private var chartCache: [String: CachedChart] = [:]
    
    struct CachedChart {
        let chart: [ChartItem]
        let calculatedAt: Date
        let dateRange: DateRangeFilter
        let entityType: EntityType
    }
    
    func getCachedChart(
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) -> [ChartItem]? {
        
        let cacheKey = "\(entityType.rawValue)_\(dateRange.startDate)_\(dateRange.endDate)"
        
        guard let cached = chartCache[cacheKey],
              cached.calculatedAt.timeIntervalSinceNow > -300 else { // 5 minute cache
            return nil
        }
        
        return cached.chart
    }
    
    func cacheChart(
        _ chart: [ChartItem],
        entityType: EntityType,
        dateRange: DateRangeFilter
    ) {
        let cacheKey = "\(entityType.rawValue)_\(dateRange.startDate)_\(dateRange.endDate)"
        chartCache[cacheKey] = CachedChart(
            chart: chart,
            calculatedAt: Date(),
            dateRange: dateRange,
            entityType: entityType
        )
    }
}
