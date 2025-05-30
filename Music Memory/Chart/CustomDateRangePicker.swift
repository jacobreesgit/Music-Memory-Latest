import SwiftUI

// MARK: - Custom Date Range Picker
struct CustomDateRangePicker: View {
    @Binding var selectedRange: DateRangeFilter
    @State private var showingCustomPicker = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("Select Time Period")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Preset buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DateRangeFilter.presetRanges, id: \.displayName) { range in
                    Button(action: {
                        selectedRange = range
                        showingCustomPicker = false
                    }) {
                        PresetRangeButtonContent(
                            title: range.displayName,
                            isSelected: selectedRange.displayName == range.displayName
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Custom range option
            Button(action: {
                showingCustomPicker.toggle()
            }) {
                PresetRangeButtonContent(
                    title: "Custom Range",
                    isSelected: showingCustomPicker,
                    icon: "calendar"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Custom date picker (expanded when selected)
            if showingCustomPicker {
                CustomDateInputView(
                    startDate: $customStartDate,
                    endDate: $customEndDate,
                    onApply: { start, end in
                        selectedRange = DateRangeFilter(
                            startDate: start,
                            endDate: end,
                            displayName: DateRangeFilter.formatCustomRange(start, end),
                            queryStrategy: DateRangeFilter.determineQueryStrategy(start: start, end: end)
                        )
                        showingCustomPicker = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Current selection info
            CurrentSelectionView(selectedRange: selectedRange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Preset Range Button Content
struct PresetRangeButtonContent: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color(.systemBackground))
        )
        .foregroundColor(isSelected ? .white : .primary)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Custom Date Input View
struct CustomDateInputView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: (Date, Date) -> Void
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isValidRange: Bool {
        startDate <= endDate && endDate <= Date()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Date pickers
            VStack(spacing: 12) {
                DatePickerRow(
                    title: "From",
                    date: $startDate,
                    icon: "calendar.badge.plus"
                )
                
                DatePickerRow(
                    title: "To",
                    date: $endDate,
                    icon: "calendar.badge.checkmark"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Error message
            if showingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    // Reset to current date
                    startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    endDate = Date()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Apply") {
                    if validateRange() {
                        onApply(startDate, endDate)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: isValidRange))
                .disabled(!isValidRange)
            }
        }
        .onChange(of: startDate) { _, _ in validateRange() }
        .onChange(of: endDate) { _, _ in validateRange() }
    }
    
    @discardableResult
    private func validateRange() -> Bool {
        showingError = false
        
        if startDate > endDate {
            errorMessage = "Start date must be before end date"
            showingError = true
            return false
        }
        
        if endDate > Date() {
            errorMessage = "End date cannot be in the future"
            showingError = true
            return false
        }
        
        let daysDifference = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysDifference > 1095 { // 3 years
            errorMessage = "Date range cannot exceed 3 years"
            showingError = true
            return false
        }
        
        return true
    }
}

// MARK: - Date Picker Row
struct DatePickerRow: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 40, alignment: .leading)
            
            Spacer()
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
}

// MARK: - Current Selection View
struct CurrentSelectionView: View {
    let selectedRange: DateRangeFilter
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Selected Period")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(queryStrategyDescription)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
            
            HStack {
                Text(selectedRange.displayName)
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text(periodInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var queryStrategyDescription: String {
        switch selectedRange.queryStrategy {
        case .useRecentPlays:
            return "High Detail"
        case .useDailyAggregates:
            return "Daily Summary"
        case .useWeeklyAggregates:
            return "Weekly Summary"
        }
    }
    
    private var periodInfo: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: selectedRange.startDate, to: selectedRange.endDate).day ?? 0
        
        if days == 0 {
            return "Today only"
        } else if days == 1 {
            return "1 day"
        } else if days < 30 {
            return "\(days) days"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    let enabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(enabled ? Color.accentColor : Color.gray)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
