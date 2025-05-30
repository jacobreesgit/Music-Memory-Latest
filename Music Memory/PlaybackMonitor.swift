import Foundation
import MediaPlayer
import Combine

// MARK: - Song Completion State
struct SongCompletionState {
    let songItem: MPMediaItem
    let startTime: Date
    var lastKnownPosition: TimeInterval = 0
    var hasBeenLogged = false
    var sessionID: String
    
    init(songItem: MPMediaItem, sessionID: String) {
        self.songItem = songItem
        self.startTime = Date()
        self.sessionID = sessionID
    }
}

// MARK: - Playback Monitor
class PlaybackMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var currentSong: MPMediaItem?
    @Published var currentPosition: TimeInterval = 0
    @Published var currentDuration: TimeInterval = 0
    @Published var completionPercentage: Double = 0
    
    private var positionTimer: Timer?
    private var currentSongState: SongCompletionState?
    private let dataManager: DataManager
    
    // Completion thresholds
    private let minimumCompletionPercentage: Double = 0.5  // 50% minimum to count as play
    private let naturalEndThreshold: TimeInterval = 5.0   // Within 5 seconds of end
    private let highCompletionThreshold: Double = 0.8     // 80% completion threshold
    
    init(dataManager: DataManager = DataManager()) {
        self.dataManager = dataManager
        setupSystemPlayerObservation()
    }
    
    // MARK: - System Player Observation
    private func setupSystemPlayerObservation() {
        let systemPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Begin receiving playback notifications
        systemPlayer.beginGeneratingPlaybackNotifications()
        
        // Monitor song changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.handleSongChange()
        }
        
        // Monitor playback state changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }
        
        // Handle app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.switchToBackgroundMode()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.switchToForegroundMode()
        }
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startPositionTimer()
        print("📱 Started playback monitoring")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        stopPositionTimer()
        print("📱 Stopped playback monitoring")
    }
    
    private func startPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPlaybackPosition()
        }
    }
    
    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    // MARK: - Position Monitoring
    private func checkPlaybackPosition() {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let currentItem = player.nowPlayingItem,
              currentItem.playbackDuration > 0 else { return }
        
        let currentTime = player.currentPlaybackTime
        let duration = currentItem.playbackDuration
        
        // Update published properties for UI
        DispatchQueue.main.async {
            self.currentSong = currentItem
            self.currentPosition = currentTime
            self.currentDuration = duration
            self.completionPercentage = currentTime / duration
        }
        
        // Update current song state
        if var songState = currentSongState {
            songState.lastKnownPosition = currentTime
            currentSongState = songState
            
            // Check for completion thresholds
            let completion = currentTime / duration
            
            // Mark as completed if >80% played or within 5 seconds of end
            if (completion >= highCompletionThreshold || (duration - currentTime) <= naturalEndThreshold)
               && !songState.hasBeenLogged {
                markSongAsCompleted()
            }
        }
    }
    
    // MARK: - Song Change Handling
    private func handleSongChange() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let newItem = player.nowPlayingItem
        
        // Evaluate previous song completion
        if let previousState = currentSongState {
            evaluatePreviousSongCompletion(previousState)
        }
        
        // Start tracking new song
        if let newItem = newItem {
            startTrackingNewSong(newItem)
        } else {
            currentSongState = nil
        }
    }
    
    private func startTrackingNewSong(_ item: MPMediaItem) {
        let sessionID = getCurrentSessionID()
        currentSongState = SongCompletionState(songItem: item, sessionID: sessionID)
        
        print("🎵 Now tracking: \(item.title ?? "Unknown") by \(item.artist ?? "Unknown")")
    }
    
    // MARK: - Completion Detection
    private func evaluatePreviousSongCompletion(_ songState: SongCompletionState) {
        guard !songState.hasBeenLogged else { return }
        
        let duration = songState.songItem.playbackDuration
        guard duration > 0 else { return }
        
        // Check if song ended naturally (within threshold of end)
        let timeDifference = duration - songState.lastKnownPosition
        let completionPercentage = songState.lastKnownPosition / duration
        
        if timeDifference <= naturalEndThreshold && completionPercentage >= minimumCompletionPercentage {
            // Song completed naturally
            logSongCompletion(songState: songState, wasNaturalEnd: true)
        } else if completionPercentage >= highCompletionThreshold {
            // Song reached high completion threshold
            logSongCompletion(songState: songState, wasNaturalEnd: false)
        }
    }
    
    private func markSongAsCompleted() {
        guard var songState = currentSongState, !songState.hasBeenLogged else { return }
        
        songState.hasBeenLogged = true
        currentSongState = songState
        
        logSongCompletion(songState: songState, wasNaturalEnd: false)
    }
    
    // MARK: - Song Completion Logging
    private func logSongCompletion(songState: SongCompletionState, wasNaturalEnd: Bool) {
        let item = songState.songItem
        let duration = item.playbackDuration
        let completionPercentage = songState.lastKnownPosition / duration
        
        // Extract identifiers
        let songID = item.persistentID.description
        let albumID = item.albumPersistentID.description
        let artistID = item.artistPersistentID.description
        
        // Determine source type
        let source: String
        if item.assetURL?.scheme == "file" {
            source = "Local"
        } else {
            source = "AppleMusic"
        }
        
        // Record the completion
        dataManager.recordSongCompletion(
            songID: songID,
            albumID: albumID,
            artistID: artistID,
            playDuration: songState.lastKnownPosition,
            completionPercentage: completionPercentage,
            source: source
        )
        
        // Update local play count for immediate UI updates
        updateLocalPlayCount(for: songID)
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .songCompletionLogged,
            object: nil,
            userInfo: [
                "songID": songID,
                "completionPercentage": completionPercentage,
                "wasNaturalEnd": wasNaturalEnd
            ]
        )
        
        print("✅ Logged completion: \(item.title ?? "Unknown") (\(Int(completionPercentage * 100))%)")
    }
    
    // MARK: - Background/Foreground Handling
    private func switchToBackgroundMode() {
        // Reduce monitoring frequency in background
        stopPositionTimer()
        print("📱 Switched to background mode - relying on notifications only")
    }
    
    private func switchToForegroundMode() {
        // Resume full position monitoring
        if isMonitoring {
            startPositionTimer()
        }
        // Sync any missed completions
        syncMissedPlays()
        print("📱 Resumed foreground monitoring")
    }
    
    private func syncMissedPlays() {
        // Check if the current song changed while in background
        let player = MPMusicPlayerController.systemMusicPlayer
        if let currentItem = player.nowPlayingItem,
           let trackedItem = currentSongState?.songItem,
           currentItem.persistentID != trackedItem.persistentID {
            // Song changed while in background
            handleSongChange()
        }
    }
    
    // MARK: - Playback State Changes
    private func handlePlaybackStateChange() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        switch player.playbackState {
        case .playing:
            if !isMonitoring {
                startMonitoring()
            }
        case .paused:
            // Keep monitoring but note pause time
            break
        case .stopped:
            // Stop monitoring after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if player.playbackState == .stopped {
                    self.stopMonitoring()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Local Play Count Management
    private func updateLocalPlayCount(for songID: String) {
        let key = "localPlayCount_\(songID)"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }
    
    func getDisplayedPlayCount(for item: MPMediaItem) -> Int {
        let songID = item.persistentID.description
        let systemPlayCount = Int(item.playCount)
        let localPlayCount = UserDefaults.standard.integer(forKey: "localPlayCount_\(songID)")
        return systemPlayCount + localPlayCount
    }
    
    // MARK: - Session Management
    private func getCurrentSessionID() -> String {
        let sessionKey = "currentSessionID"
        let lastSessionTime = "lastSessionTime"
        let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
        
        let now = Date()
        let lastTime = UserDefaults.standard.object(forKey: lastSessionTime) as? Date ?? Date.distantPast
        
        if now.timeIntervalSince(lastTime) > sessionTimeout {
            // Create new session
            let newSessionID = UUID().uuidString
            UserDefaults.standard.set(newSessionID, forKey: sessionKey)
            UserDefaults.standard.set(now, forKey: lastSessionTime)
            return newSessionID
        } else {
            // Continue existing session
            UserDefaults.standard.set(now, forKey: lastSessionTime)
            return UserDefaults.standard.string(forKey: sessionKey) ?? UUID().uuidString
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let songCompletionLogged = Notification.Name("songCompletionLogged")
}
