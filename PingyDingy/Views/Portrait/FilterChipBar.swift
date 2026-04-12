import SwiftUI

enum SortOption: String, CaseIterable {
    case timeAdded = "Time Added"
    case hostname = "Hostname"
    case lastRTT = "Last RTT"
    case avgRTT = "Avg RTT"
    case lastResponse = "Last Response"
    case lastLost = "Last Lost"
    case lossPercent = "Loss %"
    case status = "Status"
}

enum SortDirection {
    case ascending, descending
}

enum FilterOption: String, CaseIterable {
    case up = "Up"
    case down = "Down"
    case icmp = "ICMP"
    case tcp = "TCP"
    case logging = "Logging"
    case slow = "Slow >500ms"
}

struct SortBar: View {
    @Binding var sortOption: SortOption
    @Binding var sortDirection: SortDirection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Direction toggle
                Button {
                    sortDirection = sortDirection == .ascending ? .descending : .ascending
                } label: {
                    Image(systemName: sortDirection == .ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TronTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(TronTheme.chipBg)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(TronTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                }

                // Sort options
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Text(option.rawValue)
                            .neonChip()
                            .opacity(sortOption == option ? 1.0 : 0.4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct FilterChipBar: View {
    @Binding var activeFilters: Set<FilterOption>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases, id: \.self) { filter in
                    Button {
                        if activeFilters.contains(filter) {
                            activeFilters.remove(filter)
                        } else {
                            activeFilters.insert(filter)
                        }
                    } label: {
                        Text(filter.rawValue)
                            .neonChip()
                            .opacity(activeFilters.contains(filter) ? 1.0 : 0.4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
