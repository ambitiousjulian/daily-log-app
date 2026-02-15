import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [])
    private var allLogs: FetchedResults<ParentingLog>

    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Statistics") {
                    HStack {
                        Text("Total Logs")
                        Spacer()
                        Text("\(allLogs.count)")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(LogCategory.allCases) { category in
                        let count = allLogs.filter { $0.category == category.rawValue }.count
                        if count > 0 {
                            HStack {
                                Text("\(category.emoji) \(category.displayName)")
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Export") {
                    Button {
                        exportAllPDF()
                    } label: {
                        Label("Export All to PDF", systemImage: "doc.richtext")
                    }
                    .disabled(allLogs.isEmpty || isExporting)
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                    .disabled(allLogs.isEmpty)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Storage")
                        Spacer()
                        Text("Local Only")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    PersistenceController.shared.deleteAllLogs()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(allLogs.count) log entries and photos. This cannot be undone.")
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

    private func exportAllPDF() {
        isExporting = true
        let logs = Array(allLogs).sorted {
            ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
        }
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
