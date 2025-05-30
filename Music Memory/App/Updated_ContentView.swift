import SwiftUI
import MusicKit
import MediaPlayer

struct ContentView: View {
    @StateObject private var setupManager = SetupManager()
    @StateObject private var musicManager = MusicManager()
    
    @State private var selectedTab = 0
    @State private var showingChartDetail = false
    @State private var selectedChartItem: ChartItem?
    @State private var selectedDateRange = DateRangeFilter.presetRanges[1] // Last 30 Days
    
    var body: some View {
        ZStack {
            if setupManager.isSetupComplete {
                mainAppView
            } else {
                setupView
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
        .sheet(item: $selectedChartItem) { item in
            ChartItemDetailView(chartItem: item, dateRange: selectedDateRange)
        }
    }
    
    // MARK: - Main App View
    private var mainAppView: some View {
        VStack(spacing: 0) {
            // Main tab content
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                DashboardView(musicManager: musicManager)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                
                // Charts Tab
                ChartsViewWrapper(
                    selectedChartItem: $selectedChartItem,
                    selectedDateRange: $selectedDateRange
                )
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Charts")
                }
                .tag(1)
                
                // Analytics Tab
                AnalyticsView(musicManager: musicManager)
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text("Analytics")
                    }
                    .tag(2)
                
                // Settings Tab
                SettingsView(setupManager: setupManager, musicManager: musicManager)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .accentColor(.primary)
            
            // Now Playing Bar at bottom
            if musicManager.nowPlayingManager.currentSong != nil {
                NowPlayingBar()
                    .environmentObject(musicManager.nowPlayingManager)
                    .environmentObject(musicManager.playbackMonitor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Setup View
    private var setupView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Music Memory")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Personal Billboard Hot 100 Charts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Setup progress
            VStack(spacing: 16) {
                ProgressView(value: setupManager.setupProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2)
                
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
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Setup Functions
    private func setupApp() {
        Task {
            await setupManager.performSetup()
        }
    }
    
    private func startMusicTracking() {
        musicManager.startComprehensiveMonitoring()
        print("🚀 Music tracking started successfully")
    }
}

// MARK: - Charts View Wrapper
struct ChartsViewWrapper: View {
    @Binding var selectedChartItem: ChartItem?
    @Binding var selectedDateRange: DateRangeFilter
    
    var body: some View {
        NavigationView {
            ChartsView()
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    let musicManager: MusicManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
                    welcomeHeaderView
                    
                    // Current stats
                    currentStatsView
                    
                    // Quick charts preview
                    quickChartsPreview
                    
                    // Recent activity
                    recentActivityView
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var welcomeHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Welcome back!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            HStack {
                Text("Your personal music charts are ready")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var currentStatsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Listening")
                    .font(.headline)
                Spacer()
            }
            
            let todayStats = musicManager.getTodaysListeningStats()
            
            HStack(spacing: 16) {
                DashboardStatCard(
                    title: "Songs",
                    value: "\(todayStats.totalPlays)",
                    icon: "music.note",
                    color: .blue
                )
                
                DashboardStatCard(
                    title: "Time",
                    value: todayStats.formattedListeningTime,
                    icon: "clock",
                    color: .green
                )
                
                DashboardStatCard(
                    title: "Artists",
                    value: "\(todayStats.uniqueArtists)",
                    icon: "person.2",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var quickChartsPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Charts")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink("View All") {
                    ChartsView()
                }
                .font(.caption)
            }
            
            HStack(spacing: 12) {
                QuickChartCard(
                    title: "Top Songs",
                    entityType: .song,
                    icon: "music.note.list"
                )
                
                QuickChartCard(
                    title: "Top Albums",
                    entityType: .album,
                    icon: "opticaldisc"
                )
                
                QuickChartCard(
                    title: "Top Artists",
                    entityType: .artist,
                    icon: "person.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var recentActivityView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
            }
            
            let recentPlays = musicManager.dataManager.fetchRecentPlays(limit: 5)
            
            if recentPlays.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentPlays, id: \.id) { play in
                        RecentActivityRow(play: play)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Dashboard Stat Card
struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
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
        .cornerRadius(12)
    }
}

// MARK: - Quick Chart Card
struct QuickChartCard: View {
    let title: String
    let entityType: EntityType
    let icon: String
    
    var body: some View {
        NavigationLink {
            ChartsView()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity Row
struct RecentActivityRow: View {
    let play: RecentPlay
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Song completed")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(formatTime(play.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(play.completionPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(play.completionPercentage >= 0.8 ? .green : .primary)
                
                Text("\(Int(play.playDuration))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    let musicManager: MusicManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed analytics coming soon!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    let setupManager: SetupManager
    let musicManager: MusicManager
    
    var body: some View {
        NavigationView {
            Form {
                Section("Permissions") {
                    PermissionRow(
                        title: "Apple Music",
                        status: setupManager.hasAppleMusic ? "Enabled" : "Disabled",
                        color: setupManager.hasAppleMusic ? .green : .red
                    )
                    
                    PermissionRow(
                        title: "Media Library",
                        status: setupManager.hasMediaLibraryAccess ? "Enabled" : "Disabled",
                        color: setupManager.hasMediaLibraryAccess ? .green : .red
                    )
                }
                
                Section("Data") {
                    NavigationLink("Export Charts") {
                        Text("Export functionality coming soon")
                    }
                    
                    Button("Reset All Data") {
                        // TODO: Implement data reset
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        }
    }
}
