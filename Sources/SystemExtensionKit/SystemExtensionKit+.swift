//
//  SystemExtensionKit+.swift
//  SystemExtensionKit
//
//  Created by CodingIran on 2023/9/25.
//

import Foundation
@preconcurrency import SystemExtensions

public extension SystemExtensionKit {
    enum ExtensionError: LocalizedError, Sendable {
        case extensionDirectoryFailed(String, Error)
        case extensionNotExist
        case extensionCreateURLFailed(String)
        case extensionBundleIdMissing(String)
        case extensionRequestFailed(Error)
        case extensionNeedReboot
        case extensionSystemUnsupport

        public var errorDescription: String? {
            switch self {
            case let .extensionDirectoryFailed(urlStr, error):
                return "Failed to get the contents of \(urlStr): \(error.localizedDescription)"
            case .extensionNotExist:
                return "Failed to find any system extensions"
            case let .extensionCreateURLFailed(urlStr):
                return "Failed to create a bundle with URL: \(urlStr)"
            case let .extensionBundleIdMissing(urlStr):
                return "Failed to get bundleIdentifier of system extensions bundle with URL: \(urlStr)"
            case let .extensionRequestFailed(error):
                let errorDescription: String
                if let error = error as? OSSystemExtensionError {
                    errorDescription = error.code.description
                } else {
                    errorDescription = error.localizedDescription
                }
                return "Failed to request extension: \(errorDescription)"
            case .extensionNeedReboot:
                return "Failed to request extension: user need to reboot mac"
            case .extensionSystemUnsupport:
                return "Failed to request extension: system version unsupport"
            }
        }
    }

    enum ExtensionStatus: Sendable, CustomStringConvertible {
        case unknown
        case notInstalled
        case waitingApproval(OSSystemExtensionProperties)
        case installed(OSSystemExtensionProperties)

        public var isUnknown: Bool {
            switch self {
            case .unknown:
                return true
            default:
                return false
            }
        }

        public var isNotInstalled: Bool {
            switch self {
            case .notInstalled:
                return true
            default:
                return false
            }
        }

        public var isWaitingApproval: Bool {
            switch self {
            case .waitingApproval:
                return true
            default:
                return false
            }
        }

        public var isInstalled: Bool {
            switch self {
            case .installed:
                return true
            default:
                return false
            }
        }

        public var description: String {
            switch self {
            case .unknown:
                return "unknown"
            case .notInstalled:
                return "not installed"
            case .waitingApproval:
                return "waiting for userApproval"
            case .installed:
                return "installed"
            }
        }
    }
}

// MARK: - ExtensionBundle

public extension SystemExtensionKit {
    static func getExtensionBundle() throws -> Bundle {
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            throw ExtensionError.extensionDirectoryFailed(extensionsDirectoryURL.absoluteString, error)
        }
        guard let extensionURL = extensionURLs.first else {
            throw ExtensionError.extensionNotExist
        }
        guard let extensionBundle = Bundle(url: extensionURL) else {
            throw ExtensionError.extensionCreateURLFailed(extensionURL.absoluteString)
        }
        return extensionBundle
    }
}

// MARK: - OSSystemExtensionError Code Description

extension OSSystemExtensionError.Code: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .missingEntitlement:
            return "Missing Entitlement"
        case .unsupportedParentBundleLocation:
            return "Unsupported Parent Bundle Location"
        case .extensionNotFound:
            return "Extension Not found"
        case .extensionMissingIdentifier:
            return "Extension Missing Identifier"
        case .duplicateExtensionIdentifer:
            return "Duplicate Extension Identifier"
        case .unknownExtensionCategory:
            return "Unknown Extension Category"
        case .codeSignatureInvalid:
            return "Code Signature Invalid"
        case .validationFailed:
            return "Validation Failed"
        case .forbiddenBySystemPolicy:
            return "Forbidden by System Policy"
        case .requestCanceled:
            return "Request Cancelled"
        case .requestSuperseded:
            return "Request Superceeded"
        case .authorizationRequired:
            return "Authorization Required"
        @unknown default:
            return "unknown"
        }
    }
}
