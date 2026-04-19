//
//  PerformanceOptimizations.swift
//  AlerteTCL
//
//  Extensions utilitaires pour les collections et les données
//

import Foundation

// MARK: - Data Size Formatter

extension Data {
    /// Taille formatée pour le logging
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .memory)
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
