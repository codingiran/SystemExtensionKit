//
//  SystemExtensionKit+.swift
//  SystemExtensionKit
//
//  Created by CodingIran on 2023/9/25.
//

import SystemExtensions

public extension SystemExtensionKit {
    enum ExtensionError: Error {
        case extensionDirectoryFailed(String, Error)
        case extensionNotExist
        case extensionCreateURLFailed(String)
        case extensionBundleIdMissing(String)
        case extensionRequestFailed(Error)
        case extensionNeedReboot
        case extensionSystemUnsupport

        var localizedDescription: String {
            switch self {
            case .extensionDirectoryFailed(let urlStr, let error):
                return "Failed to get the contents of \(urlStr): \(error.localizedDescription)"
            case .extensionNotExist:
                return "Failed to find any system extensions"
            case .extensionCreateURLFailed(let urlStr):
                return "Failed to create a bundle with URL: \(urlStr)"
            case .extensionBundleIdMissing(let urlStr):
                return "Failed to get bundleIdentifier of system extensions bundle with URL: \(urlStr)"
            case .extensionRequestFailed(let error):
                return "Failed to request extension: \(error.localizedDescription)"
            case .extensionNeedReboot:
                return "Failed to request extension: user need to reboot mac"
            case .extensionSystemUnsupport:
                return "Failed to request extension: system version unsupport"
            }
        }
    }

    enum ExtensionStatus: CustomStringConvertible {
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

// MARK: - Error Convinience

public extension Error {
    var systemExtensionDescription: String {
        guard let error = self as? SystemExtensionKit.ExtensionError else {
            return localizedDescription
        }
        return error.localizedDescription
    }
}
