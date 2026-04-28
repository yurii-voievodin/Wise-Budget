import SwiftData

extension ModelContext {
    /// Deletes objects one-by-one so relationship fixups still run.
    func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let objects = try fetch(FetchDescriptor<T>())
        for object in objects {
            delete(object)
        }
        try save()
    }
}
