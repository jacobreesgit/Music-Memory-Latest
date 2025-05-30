import Foundation
import MediaPlayer
import Combine

// MARK: - Song Model
struct Song: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let albumID: String
    let artistID: String
    let duration: TimeInterval
    let artworkURL: URL?
    
    init(from mediaItem: MPMediaItem) {
        self.id = mediaItem.persistentID.description
        self.title = mediaItem.title ?? "Unknown Title"
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.album = mediaItem.albumTitle ?? "Unknown Album"
        self.albumID = mediaItem.albumPersistentID.description
        self.artistID = mediaItem.artistPersistentID.description
        self.duration = mediaItem.playbackDuration
        self.artworkURL = mediaItem.artwork?.image(at: CGSize(width: 300, height: 300))?.pngData().flatMap { data in
            // For now, we'll handle artwork differently since we can't directly get URLs
            // This would be enhanced with proper artwork handling
            nil
        }
    }
}

// MARK: - Now Playing Manager
class NowPlayingManager: ObservableObject {
    @Published var currentSong: Song?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying = false
    @Published var currentArtworkURL: URL?
    @Published var completionPercentage: Double = 0
    
    private var progressTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let playbackMonitor: PlaybackMonitor
    
    // Progress update interval
    private let progressUpdateInterval: TimeInterval = 0.1
    
    init(playbackMonitor: PlaybackMonitor = PlaybackMonitor()) {
        self.playbackMonitor = playbackMonitor
        setupSystemPlayerObservation()
        bindToPlaybackMonitor()
    }
    
    // MARK: - System Player Observation
    private func setupSystemPlayerObservation() {
        let systemPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Monitor now playing item changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentSong()
        }
        
        // Monitor playback state changes
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlaybackState()
        }
        
        // Initial state update
        updateCurrentSong()
        updatePlaybackState()
    }
    
    // MARK: - Bind to Playback Monitor
    private func bindToPlaybackMonitor() {
        // Sync with playback monitor's detailed tracking
        playbackMonitor.$currentPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.currentTime = position
            }
            .store(in: &cancellables)
        
        playbackMonitor.$currentDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)
        
        playbackMonitor.$completionPercentage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] percentage in
                self?.completionPercentage = percentage
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Real-Time Updates
    func startRealTimeUpdates() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: progressUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    func stopRealTimeUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else { return }
        
        let currentPlaybackTime = MPMusicPlayerController.systemMusicPlayer.currentPlaybackTime
        let playbackDuration = player.playbackDuration
        
        DispatchQueue.main.async {
            self.currentTime = currentPlaybackTime
            self.duration = playbackDuration
            
            if playbackDuration > 0 {
                self.completionPercentage = currentPlaybackTime / playbackDuration
            }
        }
    }
    
    // MARK: - State Updates
    private func updateCurrentSong() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        if let currentItem = player.nowPlayingItem {
            let song = Song(from: currentItem)
            
            DispatchQueue.main.async {
                self.currentSong = song
                self.duration = song.duration
                self.currentArtworkURL = song.artworkURL
            }
            
            // Start monitoring this song
            if !playbackMonitor.isMonitoring {
                playbackMonitor.startMonitoring()
            }
            
            // Start real-time updates
            startRealTimeUpdates()
        } else {
            DispatchQueue.main.async {
                self.currentSong = nil
                self.currentTime = 0
                self.duration = 0
                self.completionPercentage = 0
                self.currentArtworkURL = nil
            }
            
            stopRealTimeUpdates()
        }
    }
    
    private func updatePlaybackState() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        DispatchQueue.main.async {
            self.isPlaying = (player.playbackState == .playing)
        }
        
        // Manage real-time updates based on playback state
        if player.playbackState == .playing {
            startRealTimeUpdates()
        } else {
            // Keep timer running but at reduced frequency when paused
            // This helps catch resume events quickly
        }
    }
    
    private func updateCurrentTime() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let currentPlaybackTime = player.currentPlaybackTime
        
        DispatchQueue.main.async {
            self.currentTime = currentPlaybackTime
            
            if self.duration > 0 {
                self.completionPercentage = currentPlaybackTime / self.duration
            }
        }
    }
    
    // MARK: - Playback Control
    func togglePlayPause() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func skipToNext() {
        let player = MPMusicPlayerController.systemMusicPlayer
        player.skipToNextItem()
    }
    
    func skipToPrevious() {
        let player = MPMusicPlayerController.systemMusicPlayer
        player.skipToPreviousItem()
    }
    
    func seek(to percentage: Double) {
        guard duration > 0 else { return }
        
        let targetTime = duration * percentage
        let player = MPMusicPlayerController.systemMusicPlayer
        player.currentPlaybackTime = targetTime
    }
    
    // MARK: - Artwork Handling
    func getArtwork(size: CGSize) -> UIImage? {
        guard let currentItem = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem else { return nil }
        return currentItem.artwork?.image(at: size)
    }
    
    // MARK: - Session Info
    func getCurrentlyPlayingInfo() -> [String: Any] {
        guard let song = currentSong else { return [:] }
        
        return [
            "songID": song.id,
            "title": song.title,
            "artist": song.artist,
            "album": song.album,
            "albumID": song.albumID,
            "artistID": song.artistID,
            "currentTime": currentTime,
            "duration": duration,
            "completionPercentage": completionPercentage,
            "isPlaying": isPlaying
        ]
    }
    
    // MARK: - Cleanup
    deinit {
        stopRealTimeUpdates()
        NotificationCenter.default.removeObserver(self)
    }
}
