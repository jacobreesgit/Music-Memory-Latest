import SwiftUI
import MusicKit
import MediaPlayer

struct ContentView: View {
    @StateObject private var setupManager = SetupManager()
    @StateObject private var musicManager = MusicManager()
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main content area
                mainContentView
                
                // Now Playing Bar at bottom (only show when setup is complete)
                if setupManager.isSetupComplete && musicManager.nowPlayingManager.currentSong != nil {
                    NowPlayingBar()
                        .environmentObject(musicManager.nowPlayingManager)
                        .environmentObject(musicManager.playbackMonitor)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            setupApp()
        }
        .onChange(of: setupManager.isSetupComplete) { _, isComplete in
            if isComplete {
                startMusicTracking()
            }
        }
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            Spacer()
            
            // Setup or Main Interface
            if setupManager.isSetupComplete {
                mainInterfaceView
            } else {
                setupView
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Music Memory")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Personal Billboard Hot 100 Charts")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Setup View
    private var setupView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(setupManager.setupStatus)
                .font(.body)
                .multilineTextAlignment(.center)
            
            if !setupManager.hasAppleMusic && !setupManager.hasMediaLibraryAccess {
                VStack(spacing: 12) {
                    Text("Music Memory needs access to your music library to create personalized charts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Main Interface View
    private var mainInterfaceView: some View {
        VStack(spacing: 20) {
            // Setup complete indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup Complete!")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(setupManager.getDataSourceDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Current listening stats
            currentStatsView
            
            // Available features
            availableFeaturesView
            
            // Quick actions
            quickActionsView
        }
    }
    
    // MARK: - Current Stats View
    private var currentStatsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Listening")
                    .font(.headline)
                Spacer()
            }
            
            let todayStats = musicManager.getTodaysListeningStats()
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Songs",
                    value: "\(todayStats.totalPlays)",
                    icon: "music.note"
                )
                
                StatCard(
                    title: "Time",
                    value: todayStats.formattedListeningTime,
                    icon: "clock"
                )
                
                StatCard(
                    title: "Completion",
                    value: todayStats.averageCompletionPercentage,
                    icon: "chart.bar"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Available Features View
    private var availableFeaturesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Features")
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(setupManager.getAvailableFeatures(), id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.body)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions View
    private var quickActionsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ActionButton(
                    title: "View Charts",
                    icon: "chart.line.uptrend.xyaxis",
                    action: {
                        // TODO: Navigate to charts view
                        print("Navigate to charts")
                    }
                )
                
                ActionButton(
                    title: "Analytics",
                    icon: "chart.pie",
                    action: {
                        // TODO: Navigate to analytics view
                        print("Navigate to analytics")
                    }
                )
                
                ActionButton(
                    title: "Settings",
                    icon: "gear",
                    action: {
                        // TODO: Navigate to settings view
                        print("Navigate to settings")
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Setup Functions
    private func setupApp() {
        Task {
            await setupManager.performSetup()
        }
    }
    
    private func startMusicTracking() {
        // Initialize comprehensive music tracking
        musicManager.startComprehensiveMonitoring()
        print("🚀 Music tracking started successfully")
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.accentColor)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Current Session View
struct CurrentSessionView: View {
    let session: ListeningSession?
    
    var body: some View {
        Group {
            if let session = session {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Session")
                            .font(.headline)
                        Spacer()
                        Text(session.sessionDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        SessionStat(title: "Songs", value: "\(session.songsPlayed.count)")
                        SessionStat(title: "Duration", value: formatDuration(session.duration))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("No active session")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct SessionStat: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}
