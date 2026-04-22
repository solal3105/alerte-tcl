//
//  AppLogger.swift
//  AlerteTCL
//
//  Unified logger. All log sites use these APIs instead of `print`.
//  In release builds, calls compile down to nothing.
//

import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.solal.AlerteTCL"

    enum Category: String {
        case network, location, notifications, widget, viewModel, service, app
    }

    @inlinable
    static func debug(_ message: @autoclosure () -> String,
                      category: Category = .app,
                      file: StaticString = #fileID,
                      line: UInt = #line) {
        #if DEBUG
        let text = message()
        Logger(subsystem: subsystem, category: category.rawValue)
            .debug("\(text, privacy: .public) [\(file):\(line)]")
        #endif
    }

    @inlinable
    static func info(_ message: @autoclosure () -> String, category: Category = .app) {
        #if DEBUG
        let text = message()
        Logger(subsystem: subsystem, category: category.rawValue)
            .info("\(text, privacy: .public)")
        #endif
    }

    /// Errors are recorded in release too, but never expose user data.
    @inlinable
    static func error(_ message: @autoclosure () -> String, category: Category = .app) {
        let text = message()
        Logger(subsystem: subsystem, category: category.rawValue)
            .error("\(text, privacy: .public)")
    }
}

private let subsystem = AppLogger.Category.self
