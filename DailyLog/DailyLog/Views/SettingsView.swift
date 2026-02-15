import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [])
    private var allLogs: FetchedResults<ParentingLog>

    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var pdfData: Data?

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
                    .disabled(allLogs.isEmpty)
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
        }
    }

    private func exportAllPDF() {
        let logs = Array(allLogs).sorted {
            ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
        }
        pdfData = PDFExportService.generatePDF(logs: logs, context: viewContext)
        showShareSheet = true
    }
}
