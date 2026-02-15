import SwiftUI
import PhotosUI
import Photos
import ImageIO

struct LogDetailView: View {
    let category: LogCategory
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var timestamp = Date()
    @State private var timestampAutoFilled = false
    @State private var subcategory = ""
    @State private var note = ""
    @State private var amount = ""
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var photoPickerItem: PhotosPickerItem?
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

                // Timestamp
                Section {
                    DatePicker("When", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: timestamp) { _ in
                            // If user manually changes, clear the auto-fill label
                            if timestampAutoFilled {
                                timestampAutoFilled = false
                            }
                        }
                } header: {
                    Text("Date & Time")
                } footer: {
                    if timestampAutoFilled {
                        Label("Auto-filled from photo", systemImage: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
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
                    HStack {
                        Text("Photos")
                        if hasPhotos {
                            Spacer()
                            Text("\(photoEntries.count) photo\(photoEntries.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if hasPhotos {
                        Text("Each photo creates a separate log entry with its own timestamp. Swipe left to remove individual photos.")
                            .font(.caption2)
                    }
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
                    guard let item = newItem else { return }

                    // Load the image data
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        selectedImageData = data

                        // Try to get date from PHAsset (most reliable for library photos)
                        if let assetId = item.itemIdentifier {
                            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                            if let asset = result.firstObject, let creationDate = asset.creationDate {
                                timestamp = creationDate
                                timestampAutoFilled = true
                                return
                            }
                        }

                        // Fallback: extract EXIF date from image data
                        if let exifDate = Self.extractEXIFDate(from: data) {
                            timestamp = exifDate
                            timestampAutoFilled = true
                        }
                    }
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

    /// Extracts the original capture date from JPEG/HEIC EXIF metadata.
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
