//
//  SystemExtensionKit.swift
//  CodingIran
//
//  Created by CodingIran on 2023/2/9.
//

import SystemExtensions

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.5)
#error("SystemExtensionKit doesn't support Swift versions below 5.5.")
#endif

/// Current SystemExtensionKit version 1.1.4. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
public let version = "1.1.4"

public let SystemExtension = SystemExtensionKit.shared

public protocol SystemExtensionDelegate: NSObjectProtocol {
    func systemExtensionKit(_ systemExtension: SystemExtensionKit, requestResult: SystemExtensionKit.RequestResult)
}

public class SystemExtensionKit: NSObject {
    public enum ExtensionError: Error {
        case extensionDirectoryFailed(String, Error)
        case extensionNotExist
        case extensionCreateURLFailed(String)
        case extensionBundleIdMissing(String)
        case extensionRequestFailed(Error)
        case extensionNeedReboot

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
            }
        }
    }

    public enum RequestResult {
        case completed(OSSystemExtensionRequest)
        case willCompleteAfterReboot(OSSystemExtensionRequest)
        case failed(OSSystemExtensionRequest, Error)
        case needsUserApproval(OSSystemExtensionRequest)
        case replacingExtension(OSSystemExtensionRequest, String, String)
        case cancelExtension(OSSystemExtensionRequest, String, String)
    }

    public enum ExtensionStatus {
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
    }

    public static let shared = SystemExtensionKit()
    override private init() {}

    public weak var delegate: SystemExtensionDelegate?

    private var activeContinuation: CheckedContinuation<Void, Error>?
    private var propertiesContinuation: CheckedContinuation<OSSystemExtensionProperties?, Error>?
    private var guideContinuation: CheckedContinuation<Void, Never>?
    private var extensionBundle: Bundle?
    private func getExtensionBundle() throws -> Bundle {
        if let extensionBundle = extensionBundle {
            return extensionBundle
        }
        let bundle = try SystemExtensionKit.getExtensionBundle()
        extensionBundle = bundle
        return bundle
    }

    private var needForceUpdate: Bool = false

    public func activeSystemExtension(forceUpdate: Bool = false) async throws {
        needForceUpdate = forceUpdate
        // 请求 SystemExtension 授权
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                let extensionBundle = try self.getExtensionBundle()
                guard let bundleIdentifier = extensionBundle.bundleIdentifier else {
                    cont.resume(throwing: ExtensionError.extensionBundleIdMissing(extensionBundle.bundleURL.absoluteString))
                    return
                }
                self.activeContinuation = cont
                let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: bundleIdentifier, queue: .main)
                activationRequest.delegate = self
                OSSystemExtensionManager.shared.submitRequest(activationRequest)
            } catch {
                self.activeContinuation = nil
                cont.resume(throwing: error)
            }
        }
    }

    public func checkSystemExtensionStatus() async -> SystemExtensionKit.ExtensionStatus {
        if #available(macOS 12.0, *) {
            if let property = try? await enabledSystemExtensionProperty() {
                if property.isAwaitingUserApproval { return .waitingApproval(property) }
                if property.isUninstalling { return .notInstalled }
                return .installed(property)
            } else {
                return .notInstalled
            }
        } else {
            return .unknown
        }
    }

    @available(macOS 12.0, *)
    private func enabledSystemExtensionProperty() async throws -> OSSystemExtensionProperties? {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<OSSystemExtensionProperties?, Error>) in
            do {
                self.propertiesContinuation = nil
                let extensionBundle = try self.getExtensionBundle()
                guard let bundleIdentifier = extensionBundle.bundleIdentifier else {
                    cont.resume(throwing: ExtensionError.extensionBundleIdMissing(extensionBundle.bundleURL.absoluteString))
                    return
                }
                self.propertiesContinuation = cont
                let propertiesRequest = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: bundleIdentifier, queue: .main)
                propertiesRequest.delegate = self
                OSSystemExtensionManager.shared.submitRequest(propertiesRequest)
            } catch {
                self.propertiesContinuation = nil
                cont.resume(throwing: error)
            }
        }
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension SystemExtensionKit: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        defer {
            activeContinuation = nil
        }
        guard result == .completed else {
            delegate?.systemExtensionKit(self, requestResult: .willCompleteAfterReboot(request))
            activeContinuation?.resume(throwing: ExtensionError.extensionNeedReboot)
            return
        }
        delegate?.systemExtensionKit(self, requestResult: .completed(request))
        activeContinuation?.resume()
    }

    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        delegate?.systemExtensionKit(self, requestResult: .failed(request, error))
        activeContinuation?.resume(throwing: ExtensionError.extensionRequestFailed(error))
        activeContinuation = nil
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        delegate?.systemExtensionKit(self, requestResult: .needsUserApproval(request))
    }

    public func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension extension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        // existing
        let existingBundleIdentifier = existing.bundleIdentifier
        let existingBundleVersion = existing.bundleVersion
        let existingBundleShortVersion = existing.bundleShortVersion

        // `extension`
        let extensionBundleIdentifier = `extension`.bundleIdentifier
        let extensionBundleVersion = `extension`.bundleVersion
        let extensionBundleShortVersion = `extension`.bundleShortVersion

        if needForceUpdate {
            delegate?.systemExtensionKit(self, requestResult: .replacingExtension(request, existingBundleShortVersion, extensionBundleShortVersion))
            return .replace
        }
        if #available(macOS 12.0, *) {
            if existing.isAwaitingUserApproval {
                delegate?.systemExtensionKit(self, requestResult: .replacingExtension(request, existingBundleShortVersion, extensionBundleShortVersion))
                return .replace
            }
        }

        guard existingBundleIdentifier == extensionBundleIdentifier,
              existingBundleVersion == extensionBundleVersion,
              existingBundleShortVersion == extensionBundleShortVersion
        else {
            delegate?.systemExtensionKit(self, requestResult: .replacingExtension(request, existingBundleShortVersion, extensionBundleShortVersion))
            return .replace
        }

        delegate?.systemExtensionKit(self, requestResult: .cancelExtension(request, existingBundleShortVersion, extensionBundleShortVersion))
        return .cancel
    }

    @available(macOS 12.0, *)
    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        defer {
            propertiesContinuation = nil
        }
        let enabledProperty = properties.first { $0.isEnabled }
        propertiesContinuation?.resume(returning: enabledProperty)
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
