import SwiftUI
import CoreData

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ParentingLog.timestamp, ascending: false)],
        animation: .default
    )
    private var allLogs: FetchedResults<ParentingLog>

    @State private var searchText = ""
    @State private var selectedFilter: String = "All"
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var isExporting = false

    private var filterOptions: [String] {
        var options = ["All"]
        options.append(contentsOf: LogCategory.allCases.map { $0.displayName })
        return options
    }

    private var filteredLogs: [ParentingLog] {
        allLogs.filter { log in
            let matchesFilter: Bool
            if selectedFilter == "All" {
                matchesFilter = true
            } else {
                let category = LogCategory.allCases.first { $0.displayName == selectedFilter }
                matchesFilter = log.category == category?.rawValue
            }

            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = (log.note ?? "").localizedCaseInsensitiveContains(searchText)
                    || (log.category ?? "").localizedCaseInsensitiveContains(searchText)
                    || (log.subcategory ?? "").localizedCaseInsensitiveContains(searchText)
            }

            return matchesFilter && matchesSearch
        }
    }

    private var groupedLogs: [(String, [ParentingLog])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium

        var groups: [(String, [ParentingLog])] = []
        var currentDayKey = ""
        var currentGroup: [ParentingLog] = []

        for log in filteredLogs {
            guard let ts = log.timestamp else { continue }
            let dayKey = formatter.string(from: ts)

            if dayKey != currentDayKey {
                if !currentGroup.isEmpty {
                    groups.append((currentDayKey, currentGroup))
                }
                currentDayKey = dayKey
                currentGroup = [log]
            } else {
                currentGroup.append(log)
            }
        }

        if !currentGroup.isEmpty {
            groups.append((currentDayKey, currentGroup))
        }

        return groups
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filterOptions, id: \.self) { option in
                            FilterChip(
                                title: option,
                                isSelected: selectedFilter == option
                            ) {
                                selectedFilter = option
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No entries yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Start logging activities from the Log tab")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(groupedLogs, id: \.0) { day, logs in
                            Section(day) {
                                ForEach(logs, id: \.objectID) { log in
                                    TimelineRow(log: log)
                                }
                                .onDelete { indexSet in
                                    deleteItems(in: logs, at: indexSet)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Timeline")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(filteredLogs.isEmpty || isExporting)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(activityItems: [data])
                }
            }
            .overlay {
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Generating PDF...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func deleteItems(in logs: [ParentingLog], at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(logs[index])
        }
        try? viewContext.save()
    }

    private func exportPDF() {
        isExporting = true
        let logs = Array(filteredLogs)
        let context = viewContext

        Task.detached(priority: .userInitiated) {
            let data = PDFExportService.generatePDF(logs: logs, context: context)

            await MainActor.run {
                pdfData = data
                isExporting = false
                showShareSheet = true
            }
        }
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {
    let log: ParentingLog

    private var category: LogCategory {
        LogCategory(rawValue: log.category ?? "") ?? .activity
    }

    private var timeString: String {
        guard let ts = log.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: ts)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emoji badge
            Text(category.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let sub = log.subcategory, !sub.isEmpty {
                        Text("· \(sub)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let amount = log.amount, amount != 0 {
                    Text("$\(amount)")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let photoData = log.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
