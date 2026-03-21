import Foundation

/// Persists the list of bundle IDs that PetruVim should not intercept keys for.
@MainActor
final class ExcludedAppsStore {
    static let shared = ExcludedAppsStore()

    private let key = "com.petru.PetruVim.excludedBundleIDs"
    private var cachedIDs: Set<String>

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        cachedIDs = Set(stored)
    }

    var excludedBundleIDs: [String] {
        Array(cachedIDs).sorted()
    }

    func add(bundleID: String) {
        cachedIDs.insert(bundleID)
        persist()
    }

    func remove(bundleID: String) {
        cachedIDs.remove(bundleID)
        persist()
    }

    func isExcluded(_ bundleID: String) -> Bool {
        cachedIDs.contains(bundleID)
    }

    private func persist() {
        UserDefaults.standard.set(Array(cachedIDs), forKey: key)
    }
}
