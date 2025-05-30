import SwiftUI
import MediaPlayer

// MARK: - Progress Bar View
struct ProgressBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let completionThreshold: Double
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var isNearCompletion: Bool {
        progress >= completionThreshold
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 2)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 1)
                    .fill(isNearCompletion ? Color.green : Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .animation(.easeInOut(duration: 0.1), value: progress)
                
                // Completion threshold indicator
                if completionThreshold < 1.0 {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 1, height: 4)
                        .offset(x: geometry.size.width * completionThreshold - 0.5)
                }
            }
        }
    }
}

// MARK: - Playback Controls View
struct PlaybackControlsView: View {
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                nowPlayingManager.skipToPrevious()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                nowPlayingManager.togglePlayPause()
            }) {
                Image(systemName: nowPlayingManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                nowPlayingManager.skipToNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Album Artwork View
struct AlbumArtworkView: View {
    let artwork: UIImage?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let artwork = artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Song Info View
struct SongInfoView: View {
    let song: Song
    @EnvironmentObject var playbackMonitor: PlaybackMonitor
    
    var displayPlayCount: Int {
        // This would integrate with the dual tracking system
        // For now, return a placeholder
        return 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            HStack(spacing: 4) {
                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if displayPlayCount > 0 {
                    Text("• \(displayPlayCount) plays")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Time Display View
struct TimeDisplayView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        HStack(spacing: 4) {
            Text(formatTime(currentTime))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.secondary)
            
            Text("/")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(formatTime(duration))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main Now Playing Bar
struct NowPlayingBar: View {
    @StateObject private var nowPlayingManager = NowPlayingManager()
    @StateObject private var playbackMonitor = PlaybackMonitor()
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentSong = nowPlayingManager.currentSong {
                VStack(spacing: 8) {
                    // Main content row
                    HStack(spacing: 12) {
                        // Album artwork
                        AlbumArtworkView(
                            artwork: nowPlayingManager.getArtwork(size: CGSize(width: 50, height: 50)),
                            size: 50
                        )
                        
                        // Song info
                        SongInfoView(song: currentSong)
                            .environmentObject(playbackMonitor)
                        
                        Spacer()
                        
                        // Time display (when expanded)
                        if isExpanded {
                            TimeDisplayView(
                                currentTime: nowPlayingManager.currentTime,
                                duration: nowPlayingManager.duration
                            )
                        }
                        
                        // Playback controls
                        PlaybackControlsView()
                            .environmentObject(nowPlayingManager)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    // Progress bar
                    ProgressBar(
                        currentTime: nowPlayingManager.currentTime,
                        duration: nowPlayingManager.duration,
                        completionThreshold: 0.8
                    )
                    .frame(height: 2)
                    .padding(.horizontal, 16)
                    
                    // Expanded content
                    if isExpanded {
                        VStack(spacing: 12) {
                            // Additional song metadata
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Album")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(currentSong.album)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Completion")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(nowPlayingManager.completionPercentage * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(nowPlayingManager.completionPercentage >= 0.8 ? .green : .primary)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Session info
                            HStack {
                                Text("Session: \(playbackMonitor.getCurrentSessionID().prefix(8))...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Monitoring: \(playbackMonitor.isMonitoring ? "Active" : "Inactive")")
                                    .font(.caption2)
                                    .foregroundColor(playbackMonitor.isMonitoring ? .green : .orange)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color(.systemGray6))
                .overlay(
                    // Tap area indicator
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }
                )
                .cornerRadius(isExpanded ? 12 : 0)
                .shadow(color: .black.opacity(0.1), radius: isExpanded ? 8 : 0, x: 0, y: isExpanded ? -2 : 0)
            }
        }
        .onAppear {
            // Ensure both managers are connected
            playbackMonitor.startMonitoring()
        }
        .onDisappear {
            playbackMonitor.stopMonitoring()
        }
    }
}

// MARK: - Background Playback Tracker
class BackgroundPlaybackTracker: ObservableObject {
    private let playbackMonitor: PlaybackMonitor
    
    init(playbackMonitor: PlaybackMonitor) {
        self.playbackMonitor = playbackMonitor
        setupBackgroundMonitoring()
    }
    
    func setupBackgroundMonitoring() {
        // Monitor app state changes
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
    
    private func switchToBackgroundMode() {
        // Stop position timer, rely only on song change notifications
        print("📱 Switching to background tracking mode")
        // The PlaybackMonitor will handle this automatically
    }
    
    private func switchToForegroundMode() {
        // Resume full position monitoring
        print("📱 Resuming foreground tracking mode")
        playbackMonitor.startMonitoring()
        // Sync any missed completions
        syncMissedPlays()
    }
    
    private func syncMissedPlays() {
        // Check if the current song changed while in background
        // This is handled by the PlaybackMonitor's sync functionality
        print("📱 Syncing any missed plays from background")
    }
}

// MARK: - Listening Session Model
struct ListeningSession {
    let id = UUID()
    let startTime = Date()
    var endTime: Date?
    var songsPlayed: [String] = []
    
    mutating func addSongCompletion(_ songID: String) {
        songsPlayed.append(songID)
    }
    
    mutating func endSession() {
        endTime = Date()
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var sessionDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startTime)
        
        if let end = endTime {
            let endString = formatter.string(from: end)
            return "\(start) - \(endString) (\(songsPlayed.count) songs)"
        } else {
            return "Started at \(start) (\(songsPlayed.count) songs)"
        }
    }
}

// MARK: - Session Manager
class SessionManager: ObservableObject {
    @Published var currentSession: ListeningSession?
    @Published var recentSessions: [ListeningSession] = []
    
    private let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
    
    func startNewSession() {
        // End current session if it exists
        endCurrentSession()
        
        // Start new session
        currentSession = ListeningSession()
        print("📱 Started new listening session: \(currentSession!.id)")
    }
    
    func endCurrentSession() {
        guard var session = currentSession else { return }
        
        session.endSession()
        recentSessions.insert(session, at: 0)
        
        // Keep only last 50 sessions
        if recentSessions.count > 50 {
            recentSessions = Array(recentSessions.prefix(50))
        }
        
        currentSession = nil
        print("📱 Ended listening session: \(session.sessionDescription)")
    }
    
    func addSongToSession(_ songID: String) {
        guard var session = currentSession else {
            startNewSession()
            addSongToSession(songID)
            return
        }
        
        session.addSongCompletion(songID)
        currentSession = session
    }
    
    func checkSessionTimeout() {
        guard let session = currentSession else { return }
        
        let timeSinceStart = Date().timeIntervalSince(session.startTime)
        if timeSinceStart > sessionTimeout {
            endCurrentSession()
        }
    }
}
