import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCategory: LogCategory?
    @State private var showSavedBanner = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Category buttons grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(LogCategory.allCases) { category in
                                CategoryButton(category: category) {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Stats card
                        StatsCard()
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }

                // Save confirmation banner
                if showSavedBanner {
                    SavedBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationTitle("DailyLog")
            .sheet(item: $selectedCategory, onDismiss: {
                showSavedConfirmation()
            }) { category in
                LogDetailView(category: category)
            }
        }
    }

    private func showSavedConfirmation() {
        withAnimation(.spring(response: 0.4)) {
            showSavedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedBanner = false
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: LogCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(category.emoji)
                    .font(.system(size: 36))

                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(category.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(category.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ParentingLog.timestamp, ascending: false)],
        predicate: NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate
        ),
        animation: .default
    )
    private var last30DaysLogs: FetchedResults<ParentingLog>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate
        )
    )
    private var thisWeekLogs: FetchedResults<ParentingLog>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Stats")
                .font(.headline)

            HStack(spacing: 20) {
                StatItem(
                    value: "\(last30DaysLogs.count)",
                    label: "Last 30 Days"
                )

                StatItem(
                    value: "\(thisWeekLogs.count)",
                    label: "This Week"
                )

                if streak > 0 {
                    StatItem(
                        value: "\(streak)d",
                        label: "Streak"
                    )
                }

                if let topCategory = mostFrequentCategory {
                    StatItem(
                        value: topCategory.emoji,
                        label: "Top Activity"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mostFrequentCategory: LogCategory? {
        var counts: [String: Int] = [:]
        for log in last30DaysLogs {
            if let cat = log.category {
                counts[cat, default: 0] += 1
            }
        }
        guard let topRaw = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return LogCategory(rawValue: topRaw)
    }

    /// Consecutive days (ending today or yesterday) with at least one log.
    private var streak: Int {
        let calendar = Calendar.current
        var daysWithLogs = Set<Date>()
        for log in last30DaysLogs {
            guard let ts = log.timestamp else { continue }
            daysWithLogs.insert(calendar.startOfDay(for: ts))
        }

        var count = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Allow starting from yesterday if nothing logged today yet
        if !daysWithLogs.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        while daysWithLogs.contains(checkDate) {
            count += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return count
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Saved Banner

struct SavedBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Activity Logged")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.top, 8)
    }
}
