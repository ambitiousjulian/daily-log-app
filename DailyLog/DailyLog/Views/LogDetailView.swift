import SwiftUI
import PhotosUI

struct LogDetailView: View {
    let category: LogCategory
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var timestamp = Date()
    @State private var subcategory = ""
    @State private var note = ""
    @State private var amount = ""
    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isSaving = false

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
                Section("Date & Time") {
                    DatePicker("When", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
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
                        }
                    }
                }

                if category == .doctor {
                    Section("Doctor") {
                        TextField("Doctor name (optional)", text: $subcategory)
                    }
                }

                // Notes
                Section("Notes") {
                    TextField("Add notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Photo section
                Section("Photo") {
                    if let image = selectedImage {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Spacer()
                        }

                        Button("Remove Photo", role: .destructive) {
                            selectedImage = nil
                            photoPickerItem = nil
                        }
                    }

                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLog()
                    }
                    .fontWeight(.bold)
                    .disabled(isSaving)
                }
            }
            .onChange(of: photoPickerItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
        }
    }

    private func saveLog() {
        isSaving = true

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

        if let image = selectedImage {
            log.photoData = ImageCompressor.compress(image)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
            isSaving = false
        }
    }
}
