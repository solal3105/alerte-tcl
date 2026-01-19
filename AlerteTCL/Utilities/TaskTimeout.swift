//
//  TaskTimeout.swift
//  AlerteTCL
//
//  Utilitaire pour ajouter des timeouts aux Tasks et éviter les freezes
//

import Foundation

enum TaskTimeoutError: Error {
    case timedOut
    
    var localizedDescription: String {
        "L'opération a expiré"
    }
}

extension Task where Failure == Error {
    /// Exécute une tâche avec un timeout. Si le timeout est atteint, la tâche est annulée et une erreur est levée.
    /// - Parameters:
    ///   - seconds: Durée du timeout en secondes
    ///   - operation: L'opération async à exécuter
    /// - Returns: Le résultat de l'opération
    /// - Throws: TaskTimeoutError.timedOut si le timeout est atteint, ou l'erreur de l'opération
    static func withTimeout(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> Success
    ) async throws -> Success {
        try await withThrowingTaskGroup(of: Result<Success, Error>.self) { group in
            // Lancer l'opération principale
            group.addTask {
                do {
                    let value = try await operation()
                    return .success(value)
                } catch {
                    return .failure(error)
                }
            }
            
            // Lancer le timeout
            group.addTask {
                do {
                    try await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    return .failure(TaskTimeoutError.timedOut)
                } catch {
                    return .failure(TaskTimeoutError.timedOut)
                }
            }
            
            // Attendre le premier résultat (soit l'opération, soit le timeout)
            let result = try await group.next()!
            
            // Annuler l'autre tâche
            group.cancelAll()
            
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }
}

extension Task where Failure == Never {
    /// Version non-throwing de withTimeout
    static func withTimeout(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async -> Success
    ) async -> Success? {
        await withTaskGroup(of: Success?.self) { group in
            // Lancer l'opération principale
            group.addTask {
                await operation()
            }
            
            // Lancer le timeout
            group.addTask {
                try? await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            
            // Attendre le premier résultat
            let result = await group.next()!
            
            // Annuler l'autre tâche
            group.cancelAll()
            
            return result
        }
    }
}
