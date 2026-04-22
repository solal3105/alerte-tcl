//
//  SafeURL.swift
//  AlerteTCL
//
//  Replaces `URL(string: "…")!` force-unwraps. Use only for static, developer-owned URLs.
//

import Foundation

extension URL {
    /// Constructs a URL from a static literal. Traps only in debug builds
    /// so a typo is caught early; in release falls back to `about:blank`
    /// to avoid shipping a crash.
    static func trusted(_ string: StaticString) -> URL {
        let raw = "\(string)"
        if let url = URL(string: raw) {
            return url
        }
        #if DEBUG
        preconditionFailure("Invalid trusted URL literal: \(raw)")
        #else
        return URL(string: "about:blank")!
        #endif
    }
}
