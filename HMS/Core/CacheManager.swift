import Foundation

/// Thread-safe, generic in-memory cache with TTL (time-to-live) support.
/// Used across the app to avoid redundant Firestore fetches.
///
/// Usage:
/// ```
/// // Store
/// CacheManager.shared.set(staffList, forKey: "staff_list")
///
/// // Retrieve (returns nil if expired or missing)
/// let cached: [HMSUser]? = CacheManager.shared.get(forKey: "staff_list")
///
/// // Fetch with cache (returns cached immediately, refreshes in background)
/// let items = try await CacheManager.shared.fetchWithCache(
///     key: "inventory_beds",
///     ttl: 120,
///     fetch: { try await InventoryRepository.shared.fetchInventory(category: .beds) }
/// )
/// ```
final class CacheManager {
    static let shared = CacheManager()
    
    private let queue = DispatchQueue(label: "com.hms.cache", attributes: .concurrent)
    private var storage: [String: CacheEntry] = [:]
    
    /// Default TTL in seconds
    private let defaultTTL: TimeInterval = 2
    
    private init() {}
    
    // MARK: - Cache Entry
    
    private struct CacheEntry {
        let data: Any
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    // MARK: - Get / Set / Invalidate
    
    /// Retrieves a cached value if it exists and hasn't expired.
    func get<T>(forKey key: String) -> T? {
        queue.sync {
            guard let entry = storage[key], !entry.isExpired else {
                return nil
            }
            return entry.data as? T
        }
    }
    
    /// Stores a value in the cache with an optional TTL.
    func set<T>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.storage[key] = CacheEntry(
                data: value,
                timestamp: Date(),
                ttl: ttl ?? self.defaultTTL
            )
        }
    }
    
    /// Invalidates (removes) a specific cache entry.
    func invalidate(forKey key: String) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
    
    /// Invalidates all entries whose keys contain the given prefix.
    func invalidate(prefix: String) {
        queue.async(flags: .barrier) {
            self.storage = self.storage.filter { !$0.key.hasPrefix(prefix) }
        }
    }
    
    /// Removes all cached data.
    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }
    
    // MARK: - Fetch with Cache
    
    /// Returns cached data if available and fresh; otherwise fetches, caches, and returns.
    func fetchWithCache<T>(
        key: String,
        ttl: TimeInterval = 60,
        fetch: () async throws -> T
    ) async throws -> T {
        // Check cache first
        if let cached: T = get(forKey: key) {
            return cached
        }
        
        // Cache miss — fetch fresh data
        let result = try await fetch()
        set(result, forKey: key, ttl: ttl)
        return result
    }
    
    /// Force-refreshes: fetches fresh data, updates cache, and returns it.
    func forceRefresh<T>(
        key: String,
        ttl: TimeInterval = 60,
        fetch: () async throws -> T
    ) async throws -> T {
        let result = try await fetch()
        set(result, forKey: key, ttl: ttl)
        return result
    }
}
