import SwiftUI
import PhotosUI
import Photos
import ImageIO

/// Holds one photo and its extracted (or manually set) timestamp.
struct PhotoEntry: Identifiable {
    let id = UUID()
    var image: UIImage
    var timestamp: Date
    var autoFilled: Bool
}

struct LogDetailView: View {
    let category: LogCategory
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    // Shared fields (applied to every entry)
    @State private var timestamp = Date()          // used only when there are NO photos
    @State private var subcategory = ""
    @State private var note = ""
    @State private var amount = ""

    // Photo state
    @State private var photoEntries: [PhotoEntry] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var isLoadingPhotos = false

    @State private var isSaving = false

    private enum Field: Hashable {
        case amount, note, doctor
    }

    private var hasPhotos: Bool { !photoEntries.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // Header section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text(category.emoji)
                                .font(.system(size: 56))
                            Text(category.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Timestamp — only shown when there are no photos
                if !hasPhotos {
                    Section("Date & Time") {
                        DatePicker("When", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                // Conditional fields
                if let subcategories = category.subcategories {
                    Section("Details") {
                        Picker("Type", selection: $subcategory) {
                            Text("Select...").tag("")
                            ForEach(subcategories, id: \.self) { sub in
                                Text(sub).tag(sub)
                            }
                        }
                    }
                }

                if category == .purchase {
                    Section("Amount") {
                        HStack {
                            Text("$")
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)
                        }
                    }
                }

                if category == .doctor {
                    Section("Doctor") {
                        TextField("Doctor name (optional)", text: $subcategory)
                            .focused($focusedField, equals: .doctor)
                    }
                }

                // Notes
                Section("Notes") {
                    TextField("Add notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .note)
                }

                // Photos section
                Section {
                    if isLoadingPhotos {
                        HStack {
                            Spacer()
                            ProgressView("Loading photos…")
                            Spacer()
                        }
                    }

                    // Show each selected photo with its timestamp
                    ForEach($photoEntries) { $entry in
                        VStack(spacing: 8) {
                            Image(uiImage: entry.image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            DatePicker(
                                "Taken",
                                selection: $entry.timestamp,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .font(.caption)

                            if entry.autoFilled {
                                Label("From photo metadata", systemImage: "camera.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        photoEntries.remove(atOffsets: indexSet)
                    }

                    // Add photos buttons
                    PhotosPicker(
                        selection: $photoPickerItems,
                        maxSelectionCount: 20,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(hasPhotos ? "Add More from Library" : "Choose from Library",
                              systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }

                    if hasPhotos {
                        Button("Remove All Photos", role: .destructive) {
                            photoEntries.removeAll()
                            photoPickerItems.removeAll()
                        }
                    }
                } header: {
                    photosHeader
                } footer: {
                    photosFooter
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasPhotos ? "Save \(photoEntries.count)" : "Save") {
                        saveLog()
                    }
                    .fontWeight(.bold)
                    .disabled(isSaving || isLoadingPhotos)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: photoPickerItems) { newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await loadPickerItems(newItems)
                    // Reset picker so the user can pick again later
                    photoPickerItems = []
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $cameraImage)
            }
            .onChange(of: cameraImage) { newImage in
                if let image = newImage {
                    let entry = PhotoEntry(image: image, timestamp: Date(), autoFilled: false)
                    photoEntries.append(entry)
                    cameraImage = nil
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(hasPhotos ? "Saving \(photoEntries.count) \(photoEntries.count == 1 ? "entry" : "entries")..." : "Saving...")
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

    // MARK: - Section Header / Footer

    @ViewBuilder
    private var photosHeader: some View {
        HStack {
            Text("Photos")
            if hasPhotos {
                Spacer()
                Text("\(photoEntries.count) photo\(photoEntries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var photosFooter: some View {
        if hasPhotos {
            Text("Each photo creates a separate log entry with its own timestamp. Swipe left to remove individual photos.")
                .font(.caption2)
        }
    }

    // MARK: - Section Header / Footer

    @ViewBuilder
    private var photosHeader: some View {
        HStack {
            Text("Photos")
            if hasPhotos {
                Spacer()
                Text("\(photoEntries.count) photo\(photoEntries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var photosFooter: some View {
        if hasPhotos {
            Text("Each photo creates a separate log entry with its own timestamp. Swipe left to remove individual photos.")
                .font(.caption2)
        }
    }

    // MARK: - Load Photos from Picker

    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }

            var photoDate: Date = Date()
            var wasAutoFilled = false

            // Try PHAsset first (most reliable for library photos)
            if let assetId = item.itemIdentifier {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                if let asset = result.firstObject, let creationDate = asset.creationDate {
                    photoDate = creationDate
                    wasAutoFilled = true
                }
            }

            // Fallback: EXIF
            if !wasAutoFilled, let exifDate = Self.extractEXIFDate(from: data) {
                photoDate = exifDate
                wasAutoFilled = true
            }

            let entry = PhotoEntry(image: uiImage, timestamp: photoDate, autoFilled: wasAutoFilled)
            await MainActor.run {
                photoEntries.append(entry)
            }
        }
    }

    // MARK: - EXIF Date Extraction

    static func extractEXIFDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    // MARK: - Save

    private func saveLog() {
        isSaving = true
        focusedField = nil

        let haptic = UINotificationFeedbackGenerator()

        if hasPhotos {
            // Create one log entry per photo
            for entry in photoEntries {
                let log = ParentingLog(context: viewContext)
                log.id = UUID()
                log.timestamp = entry.timestamp
                log.category = category.rawValue
                log.note = note.isEmpty ? nil : note

                if !subcategory.isEmpty {
                    log.subcategory = subcategory
                }
                if category == .purchase, let amountValue = Decimal(string: amount) {
                    log.amount = amountValue as NSDecimalNumber
                }

                log.photoData = ImageCompressor.compress(entry.image)
            }
        } else {
            // Single entry with no photo
            let log = ParentingLog(context: viewContext)
            log.id = UUID()
            log.timestamp = timestamp
            log.category = category.rawValue
            log.note = note.isEmpty ? nil : note

            if !subcategory.isEmpty {
                log.subcategory = subcategory
            }
            if category == .purchase, let amountValue = Decimal(string: amount) {
                log.amount = amountValue as NSDecimalNumber
            }
        }

        do {
            try viewContext.save()
            haptic.notificationOccurred(.success)
            dismiss()
        } catch {
            haptic.notificationOccurred(.error)
            print("Save error: \(error)")
            isSaving = false
        }
    }
}
