//
//  PerformanceOptimizations.swift
//  AlerteTCL
//
//  Utilitaires d'optimisation des performances pour le chargement et le traitement des données
//

import Foundation

// MARK: - Optimized JSON Decoder

/// Décodeur JSON optimisé avec réutilisation et configuration pré-configurée
enum OptimizedDecoder {
    
    /// Décodeur partagé thread-safe pour les réponses API standard
    /// Utilise un pool de décodeurs pour éviter la création répétée
    private static let decoderPool = DecoderPool(size: 4)
    
    /// Décode des données JSON avec un décodeur optimisé du pool
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = decoderPool.acquire()
        defer { decoderPool.release(decoder) }
        return try decoder.decode(type, from: data)
    }
    
    /// Pool de décodeurs pour réutilisation
    private final class DecoderPool: @unchecked Sendable {
        private var available: [JSONDecoder]
        private let lock = NSLock()
        private let maxSize: Int
        
        init(size: Int) {
            self.maxSize = size
            self.available = (0..<size).map { _ in Self.createDecoder() }
        }
        
        private static func createDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .useDefaultKeys
            return decoder
        }
        
        func acquire() -> JSONDecoder {
            lock.lock()
            defer { lock.unlock() }
            
            if let decoder = available.popLast() {
                return decoder
            }
            return Self.createDecoder()
        }
        
        func release(_ decoder: JSONDecoder) {
            lock.lock()
            defer { lock.unlock() }
            
            if available.count < maxSize {
                available.append(decoder)
            }
        }
    }
}

// MARK: - Data Size Formatter

extension Data {
    /// Taille formatée pour le logging
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .memory)
    }
}

// MARK: - Batch Processing

/// Utilitaire pour traiter des données par lots sans bloquer le thread principal
enum BatchProcessor {
    
    /// Traite un tableau par lots avec possibilité d'annulation
    static func process<T, R>(
        items: [T],
        batchSize: Int = 100,
        transform: @escaping (T) -> R
    ) async -> [R] {
        var results: [R] = []
        results.reserveCapacity(items.count)
        
        for batch in items.chunked(into: batchSize) {
            // Vérifier l'annulation
            if Task.isCancelled { break }
            
            // Traiter le lot
            let batchResults = batch.map(transform)
            results.append(contentsOf: batchResults)
            
            // Yield pour permettre à d'autres tâches de s'exécuter
            await Task.yield()
        }
        
        return results
    }
    
    /// Traite un tableau par lots avec progression
    static func processWithProgress<T, R>(
        items: [T],
        batchSize: Int = 100,
        transform: @escaping (T) -> R,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async -> [R] {
        var results: [R] = []
        results.reserveCapacity(items.count)
        
        let total = items.count
        var processed = 0
        
        for batch in items.chunked(into: batchSize) {
            if Task.isCancelled { break }
            
            let batchResults = batch.map(transform)
            results.append(contentsOf: batchResults)
            
            processed += batch.count
            let progress = Double(processed) / Double(total)
            
            await onProgress(progress)
            await Task.yield()
        }
        
        return results
    }
}

// MARK: - Array Chunking

extension Array {
    /// Divise le tableau en sous-tableaux de taille fixe
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Debouncer

/// Debouncer générique pour limiter la fréquence d'appels
@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: UInt64
    
    /// Crée un debouncer avec le délai spécifié en millisecondes
    init(delayMs: Int) {
        self.delay = UInt64(delayMs) * 1_000_000
    }
    
    /// Exécute l'action après le délai, annulant tout appel précédent
    func debounce(action: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    
    /// Annule l'action en attente
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Throttler

/// Throttler pour limiter la fréquence d'exécution
@MainActor
final class Throttler {
    private var lastExecution: Date = .distantPast
    private let interval: TimeInterval
    
    /// Crée un throttler avec l'intervalle minimum entre exécutions
    init(intervalMs: Int) {
        self.interval = TimeInterval(intervalMs) / 1000.0
    }
    
    /// Exécute l'action seulement si l'intervalle minimum est passé
    func throttle(action: () -> Void) {
        let now = Date()
        if now.timeIntervalSince(lastExecution) >= interval {
            lastExecution = now
            action()
        }
    }
}

// MARK: - Memory-Efficient Set Operations

extension Set {
    /// Intersection optimisée qui choisit l'algorithme selon la taille
    func efficientIntersection(with other: Set<Element>) -> Set<Element> {
        // Itérer sur le plus petit ensemble
        if self.count <= other.count {
            return self.filter { other.contains($0) }
        } else {
            return other.filter { self.contains($0) }
        }
    }
}

// MARK: - Lazy Filtering

extension Sequence {
    /// Filtre paresseux qui s'arrête après avoir trouvé n éléments
    func lazyFilter(maxResults: Int, where predicate: (Element) -> Bool) -> [Element] {
        var results: [Element] = []
        results.reserveCapacity(maxResults)
        
        for element in self {
            if predicate(element) {
                results.append(element)
                if results.count >= maxResults {
                    break
                }
            }
        }
        
        return results
    }
}

// MARK: - Request Coalescing

/// Coalesce multiple requests into a single one
actor RequestCoalescer<Key: Hashable, Value> {
    private var pendingRequests: [Key: Task<Value, Error>] = [:]
    
    /// Exécute une requête, ou retourne le résultat d'une requête identique en cours
    func request(key: Key, execute: @escaping () async throws -> Value) async throws -> Value {
        // Si une requête identique est déjà en cours, attendre son résultat
        if let existingTask = pendingRequests[key] {
            return try await existingTask.value
        }
        
        // Créer une nouvelle tâche
        let task = Task {
            try await execute()
        }
        
        pendingRequests[key] = task
        
        defer {
            pendingRequests.removeValue(forKey: key)
        }
        
        return try await task.value
    }
}

// MARK: - Preloading Manager

/// Gestionnaire de préchargement intelligent
actor PreloadManager {
    static let shared = PreloadManager()
    
    private var preloadedData: [String: Any] = [:]
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    /// Précharge des données en arrière-plan avec priorité basse
    func preload<T>(
        key: String,
        loader: @escaping () async throws -> T
    ) {
        guard preloadTasks[key] == nil else { return }
        
        preloadTasks[key] = Task.detached(priority: .background) { [weak self] in
            do {
                let data = try await loader()
                await self?.store(key: key, data: data)
            } catch {
                print("⚠️ PreloadManager: Échec préchargement '\(key)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Récupère les données préchargées
    func get<T>(key: String) -> T? {
        preloadedData[key] as? T
    }
    
    /// Vérifie si des données sont préchargées
    func has(key: String) -> Bool {
        preloadedData[key] != nil
    }
    
    private func store(key: String, data: Any) {
        preloadedData[key] = data
        preloadTasks.removeValue(forKey: key)
        print("✅ PreloadManager: '\(key)' préchargé")
    }
    
    /// Vide le cache de préchargement
    func clear() {
        preloadedData.removeAll()
        for task in preloadTasks.values {
            task.cancel()
        }
        preloadTasks.removeAll()
    }
}
