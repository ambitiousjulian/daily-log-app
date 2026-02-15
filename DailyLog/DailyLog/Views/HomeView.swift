import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCategory: LogCategory?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Category buttons grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(LogCategory.allCases) { category in
                            CategoryButton(category: category) {
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
            .navigationTitle("DailyLog")
            .sheet(item: $selectedCategory) { category in
                LogDetailView(category: category)
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

            HStack(spacing: 24) {
                StatItem(
                    value: "\(last30DaysLogs.count)",
                    label: "Last 30 Days"
                )

                StatItem(
                    value: "\(thisWeekLogs.count)",
                    label: "This Week"
                )

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
