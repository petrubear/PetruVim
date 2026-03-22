import Foundation

/// Persists the list of bundle IDs that PetruVim should intercept keys for.
/// - Empty list → Vim keys active in all apps (default behaviour).
/// - Non-empty list → Vim keys active only in the listed apps.
@MainActor
final class IncludedAppsStore {
    static let shared = IncludedAppsStore()

    private let key = "com.petru.PetruVim.includedBundleIDs"
    private var cachedIDs: Set<String>

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        cachedIDs = Set(stored)
    }

    var includedBundleIDs: [String] {
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

    /// Returns true when the key event should be blocked (passed through to the app).
    /// Empty list → Vim active everywhere (nothing blocked).
    /// Non-empty list → block any app not in the list.
    func isBlocked(_ bundleID: String) -> Bool {
        if cachedIDs.isEmpty { return false }
        return !cachedIDs.contains(bundleID)
    }

    private func persist() {
        UserDefaults.standard.set(Array(cachedIDs), forKey: key)
    }
}
