import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ParentingLog")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Enable file protection - encrypts data when device is locked
            let description = container.persistentStoreDescriptions.first
            description?.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Convenience Methods

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    func deleteLog(_ log: ParentingLog) {
        viewContext.delete(log)
        save()
    }

    func deleteAllLogs() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ParentingLog.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDelete.resultType = .resultTypeObjectIDs

        do {
            let result = try viewContext.execute(batchDelete) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [viewContext]
            )
        } catch {
            print("Batch delete error: \(error)")
        }
    }

    func logCount() -> Int {
        let request: NSFetchRequest<ParentingLog> = ParentingLog.fetchRequest()
        return (try? viewContext.count(for: request)) ?? 0
    }

    func logCount(since date: Date) -> Int {
        let request: NSFetchRequest<ParentingLog> = ParentingLog.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", date as NSDate)
        return (try? viewContext.count(for: request)) ?? 0
    }

    func logCount(forCategory category: String, since date: Date) -> Int {
        let request: NSFetchRequest<ParentingLog> = ParentingLog.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND category == %@",
            date as NSDate, category
        )
        return (try? viewContext.count(for: request)) ?? 0
    }

    func fetchLogs(
        category: String? = nil,
        searchText: String? = nil
    ) -> [ParentingLog] {
        let request: NSFetchRequest<ParentingLog> = ParentingLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ParentingLog.timestamp, ascending: false)]

        var predicates: [NSPredicate] = []

        if let category = category, !category.isEmpty {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        if let searchText = searchText, !searchText.isEmpty {
            predicates.append(NSPredicate(format: "note CONTAINS[cd] %@", searchText))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        return (try? viewContext.fetch(request)) ?? []
    }

    // Preview helper
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        for i in 0..<10 {
            let log = ParentingLog(context: context)
            log.id = UUID()
            log.timestamp = Date().addingTimeInterval(Double(-i * 3600))
            log.category = LogCategory.allCases.randomElement()?.rawValue ?? "meal"
            log.note = "Sample log entry #\(i + 1)"
        }

        try? context.save()
        return controller
    }()
}
