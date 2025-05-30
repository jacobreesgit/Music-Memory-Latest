import Foundation
import MusicKit
import MediaPlayer
import Combine

// MARK: - Enhanced Music Manager
class MusicManager: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    
    // Core tracking components
    @Published var playbackMonitor: PlaybackMonitor
    @Published var nowPlayingManager: NowPlayingManager
    @Published var sessionManager = SessionManager()
    
    private var dataManager: DataManager
    private var backgroundTracker: BackgroundPlaybackTracker
    private var cancellables = Set<AnyCancellable>()
    
    init(dataManager: DataManager = DataManager()) {
        self.dataManager = dataManager
        self.playbackMonitor = PlaybackMonitor(dataManager: dataManager)
        self.nowPlayingManager = NowPlayingManager(playbackMonitor: playbackMonitor)
        self.backgroundTracker = BackgroundPlaybackTracker(playbackMonitor: playbackMonitor)
        
        setupIntegration()
        checkInitialAuthorizationStatus()
    }
    
    // MARK: - Integration Setup
    private func setupIntegration() {
        // Monitor song completions for session management
        NotificationCenter.default.addObserver(
            forName: .songCompletionLogged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let songID = notification.userInfo?["songID"] as? String {
                self?.sessionManager.addSongToSession(songID)
            }
        }
        
        // Monitor playback state for session timeout
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.sessionManager.checkSessionTimeout()
        }
    }
    
    // MARK: - Authorization Status Check
    private func checkInitialAuthorizationStatus() {
        // Check current MusicKit status
        switch MusicAuthorization.currentStatus {
        case .authorized:
            authorizationStatus = .authorized
        case .denied:
            authorizationStatus = .denied
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .restricted:
            authorizationStatus = .restricted
        @unknown default:
            authorizationStatus = .notDetermined
        }
        
        // Check current MediaPlayer status
        mediaLibraryStatus = MPMediaLibrary.authorizationStatus()
    }
    
    // MARK: - Authorization Requests
    func requestMusicAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.authorizationStatus = status
            print("🎵 MusicKit authorization: \(status)")
        }
    }
    
    func requestMediaLibraryAuthorization() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.mediaLibraryStatus = status
                print("📱 MediaPlayer authorization: \(status)")
                
                // Start monitoring if authorized
                if status == .authorized {
                    self?.startComprehensiveMonitoring()
                }
            }
        }
    }
    
    // MARK: - Comprehensive Monitoring
    func startComprehensiveMonitoring() {
        guard mediaLibraryStatus == .authorized else {
            print("⚠️ Cannot start monitoring without MediaPlayer authorization")
            return
        }
        
        // Start all monitoring components
        playbackMonitor.startMonitoring()
        nowPlayingManager.startRealTimeUpdates()
        
        // Start a new session if none exists
        if sessionManager.currentSession == nil {
            sessionManager.startNewSession()
        }
        
        print("🚀 Started comprehensive music monitoring")
    }
    
    func stopComprehensiveMonitoring() {
        playbackMonitor.stopMonitoring()
        nowPlayingManager.stopRealTimeUpdates()
        sessionManager.endCurrentSession()
        
        print("🛑 Stopped comprehensive music monitoring")
    }
    
    // MARK: - Playback Control Integration
    func togglePlayPause() {
        nowPlayingManager.togglePlayPause()
    }
    
    func skipToNext() {
        nowPlayingManager.skipToNext()
    }
    
    func skipToPrevious() {
        nowPlayingManager.skipToPrevious()
    }
    
    func seek(to percentage: Double) {
        nowPlayingManager.seek(to: percentage)
    }
    
    // MARK: - Data Access Methods
    func getCurrentPlayingInfo() -> [String: Any] {
        return nowPlayingManager.getCurrentlyPlayingInfo()
    }
    
    func getDisplayedPlayCount(for item: MPMediaItem) -> Int {
        return playbackMonitor.getDisplayedPlayCount(for: item)
    }
    
    func getCurrentSession() -> ListeningSession? {
        return sessionManager.currentSession
    }
    
    func getRecentSessions(limit: Int = 10) -> [ListeningSession] {
        return Array(sessionManager.recentSessions.prefix(limit))
    }
    
    // MARK: - Music Library Access
    func searchLibrary(query: String) -> [MPMediaItem] {
        guard mediaLibraryStatus == .authorized else { return [] }
        
        let searchQuery = MPMediaQuery.songs()
        let predicate = MPMediaPropertyPredicate(
            value: query,
            forProperty: MPMediaItemPropertyTitle,
            comparisonType: .contains
        )
        searchQuery.addFilterPredicate(predicate)
        
        return searchQuery.items ?? []
    }
    
    func getRecentlyPlayed(limit: Int = 50) -> [MPMediaItem] {
        guard mediaLibraryStatus == .authorized else { return [] }
        
        let query = MPMediaQuery.songs()
        let items = query.items ?? []
        
        // Filter items that have lastPlayedDate and sort manually
        let itemsWithPlayDate = items.filter { $0.lastPlayedDate != nil }
        let sortedItems = itemsWithPlayDate.sorted { item1, item2 in
            guard let date1 = item1.lastPlayedDate,
                  let date2 = item2.lastPlayedDate else { return false }
            return date1 > date2
        }
        
        return Array(sortedItems.prefix(limit))
    }
    
    func getMostPlayed(limit: Int = 50) -> [MPMediaItem] {
        guard mediaLibraryStatus == .authorized else { return [] }
        
        let query = MPMediaQuery.songs()
        let items = query.items ?? []
        
        // Sort by play count (system + local)
        let sortedItems = items.sorted { item1, item2 in
            let count1 = getDisplayedPlayCount(for: item1)
            let count2 = getDisplayedPlayCount(for: item2)
            return count1 > count2
        }
        
        return Array(sortedItems.prefix(limit))
    }
    
    // MARK: - Apple Music Integration
    @available(iOS 15.0, *)
    func searchAppleMusic(query: String) async throws -> [Song] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        let request = MusicCatalogSearchRequest(
            term: query,
            types: [MusicKit.Song.self]
        )
        
        let response = try await request.response()
        
        return response.songs.compactMap { song in
            // Convert MusicKit.Song to our Song model
            // This would need proper implementation based on MusicKit's Song structure
            return nil // Placeholder for now
        }
    }
    
    // MARK: - Statistics and Analytics
    func getTodaysListeningStats() -> ListeningStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let recentPlays = dataManager.fetchRecentPlays(limit: 1000)
        let todaysPlays = recentPlays.filter { play in
            play.timestamp >= today && play.timestamp < tomorrow
        }
        
        let totalPlays = todaysPlays.count
        let totalListeningTime = todaysPlays.reduce(0) { $0 + $1.playDuration }
        let uniqueSongs = Set(todaysPlays.map { $0.songID }).count
        let uniqueArtists = Set(todaysPlays.map { $0.artistID }).count
        
        return ListeningStats(
            totalPlays: totalPlays,
            totalListeningTime: totalListeningTime,
            uniqueSongs: uniqueSongs,
            uniqueArtists: uniqueArtists,
            averageCompletion: todaysPlays.isEmpty ? 0 : todaysPlays.reduce(0) { $0 + $1.completionPercentage } / Double(todaysPlays.count)
        )
    }
    
    func getWeeklyListeningStats() -> ListeningStats {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let recentPlays = dataManager.fetchRecentPlays(limit: 10000)
        let weekPlays = recentPlays.filter { play in
            play.timestamp >= weekAgo
        }
        
        let totalPlays = weekPlays.count
        let totalListeningTime = weekPlays.reduce(0) { $0 + $1.playDuration }
        let uniqueSongs = Set(weekPlays.map { $0.songID }).count
        let uniqueArtists = Set(weekPlays.map { $0.artistID }).count
        
        return ListeningStats(
            totalPlays: totalPlays,
            totalListeningTime: totalListeningTime,
            uniqueSongs: uniqueSongs,
            uniqueArtists: uniqueArtists,
            averageCompletion: weekPlays.isEmpty ? 0 : weekPlays.reduce(0) { $0 + $1.completionPercentage } / Double(weekPlays.count)
        )
    }
    
    // MARK: - Cleanup
    deinit {
        stopComprehensiveMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Listening Statistics Model
struct ListeningStats {
    let totalPlays: Int
    let totalListeningTime: TimeInterval
    let uniqueSongs: Int
    let uniqueArtists: Int
    let averageCompletion: Double
    
    var formattedListeningTime: String {
        let hours = Int(totalListeningTime) / 3600
        let minutes = (Int(totalListeningTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var averageCompletionPercentage: String {
        return "\(Int(averageCompletion * 100))%"
    }
}

// MARK: - Error Types
enum MusicKitError: Error {
    case notAuthorized
    case networkError
    case unknownError
    
    var localizedDescription: String {
        switch self {
        case .notAuthorized:
            return "Apple Music access not authorized"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
