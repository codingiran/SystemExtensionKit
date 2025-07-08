//
//  SystemExtensionRequest.swift
//  SystemExtensionkit
//
//  Created by CodingIran on 2023/9/25.
//

#if DEBUG
    import os.log
#endif
@preconcurrency import SystemExtensions

public class SystemExtensionRequest: NSObject, @unchecked Sendable {
    public let action: SystemExtensionRequest.Action
    public let bundleIdentifier: String
    public let request: OSSystemExtensionRequest

    private var continuation: CheckedContinuation<SystemExtensionRequest.Result, Error>?

    private var requestUpdater: SystemExtensionRequestUpdating?

    required init(action: SystemExtensionRequest.Action, bundleIdentifier: String, request: OSSystemExtensionRequest) {
        self.action = action
        self.bundleIdentifier = bundleIdentifier
        self.request = request
        super.init()
    }

    convenience init(action: SystemExtensionRequest.Action, queue: DispatchQueue) throws {
        let extBundle = try SystemExtensionKit.getExtensionBundle()
        guard let bundleIdentifier = extBundle.bundleIdentifier else {
            throw SystemExtensionKit.ExtensionError.extensionBundleIdMissing(extBundle.bundleURL.absoluteString)
        }
        let request: OSSystemExtensionRequest
        switch action {
        case .activate:
            request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: bundleIdentifier, queue: queue)
        case .deactivate:
            request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: bundleIdentifier, queue: queue)
        case .properties:
            if #available(macOS 12.0, *) {
                request = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: bundleIdentifier, queue: queue)
            } else {
                throw SystemExtensionKit.ExtensionError.extensionSystemUnsupport
            }
        }
        self.init(action: action, bundleIdentifier: bundleIdentifier, request: request)
    }

    deinit {
        continuation = nil
        #if DEBUG
            if #available(macOS 11.0, *) { os_log("Deinit SystemExtension request for %{public}s", self.request.identifier) }
        #endif
    }

    @discardableResult
    public func submit(requestUpdater: SystemExtensionRequestUpdating?) async throws -> SystemExtensionRequest.Result {
        self.requestUpdater = requestUpdater
        self.requestUpdater?.systemExtensionRequest(self, updateProgress: .submitting)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SystemExtensionRequest.Result, Error>) in
            self.continuation = nil
            self.request.delegate = self
            OSSystemExtensionManager.shared.submitRequest(self.request)
            #if DEBUG
                if #available(macOS 11.0, *) { os_log("submit SystemExtension request for %{public}s", self.request.identifier) }
            #endif
            self.continuation = cont
        }
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    public func request(_: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        switch action {
        case let .activate(forceUpdate):
            // existing
            let existingBundleIdentifier = existing.bundleIdentifier
            let existingBundleVersion = existing.bundleVersion
            let existingBundleShortVersion = existing.bundleShortVersion
            let existingVersion = existingBundleShortVersion + "(\(existingBundleVersion))"

            // ext
            let extBundleIdentifier = ext.bundleIdentifier
            let extBundleVersion = ext.bundleVersion
            let extBundleShortVersion = ext.bundleShortVersion
            let extVersion = extBundleShortVersion + "(\(extBundleVersion))"

            if forceUpdate {
                updatingReplacingExtension(existingVersion: existingVersion, extVersion: extVersion)
                return .replace
            }

            if #available(macOS 12.0, *) {
                if existing.isAwaitingUserApproval {
                    updatingReplacingExtension(existingVersion: existingVersion, extVersion: extVersion)
                    return .replace
                }
            }

            guard existingBundleIdentifier == extBundleIdentifier,
                  existingBundleVersion == extBundleVersion,
                  existingBundleShortVersion == extBundleShortVersion
            else {
                updatingReplacingExtension(existingVersion: existingVersion, extVersion: extVersion)
                return .replace
            }

            updatingCancelExtension(existingVersion: existingVersion, extVersion: extVersion)
            return .cancel
        default:
            return .cancel
        }
    }

    public func requestNeedsUserApproval(_: OSSystemExtensionRequest) {
        requestUpdater?.systemExtensionRequest(self, updateProgress: .needsUserApproval)
    }

    public func request(_: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        defer { continuation = nil }
        guard result == .completed else {
            requestUpdater?.systemExtensionRequest(self, updateProgress: .willCompleteAfterReboot)
            continuation?.resume(throwing: SystemExtensionKit.ExtensionError.extensionNeedReboot)
            return
        }
        requestUpdater?.systemExtensionRequest(self, updateProgress: .completed)
        continuation?.resume(returning: .init(enabledProperty: nil))
    }

    public func request(_: OSSystemExtensionRequest, didFailWithError error: Error) {
        defer { continuation = nil }
        let extensionError = SystemExtensionKit.ExtensionError.extensionRequestFailed(error)
        requestUpdater?.systemExtensionRequest(self, updateProgress: .failed(extensionError))
        continuation?.resume(throwing: extensionError)
    }

    @available(macOS 12.0, *)
    public func request(_: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        defer { continuation = nil }
        var enabledProperty: OSSystemExtensionProperties?
        for property in properties {
            if property.isEnabled {
                enabledProperty = property
                break
            }
            if property.isAwaitingUserApproval {
                enabledProperty = property
            }
        }
        continuation?.resume(returning: .init(enabledProperty: enabledProperty))
    }
}

// MARK: - SystemExtensionRequestUpdating callback

private extension SystemExtensionRequest {
    private func updatingReplacingExtension(existingVersion: String, extVersion: String) {
        requestUpdater?.systemExtensionRequest(self, updateProgress: .replacingExtension(existingVersion: existingVersion, extVersion: extVersion))
    }

    private func updatingCancelExtension(existingVersion: String, extVersion: String) {
        requestUpdater?.systemExtensionRequest(self, updateProgress: .cancelExtension(existingVersion: existingVersion, extVersion: extVersion))
    }
}

public extension SystemExtensionRequest {
    enum Action: Sendable, CustomStringConvertible {
        case activate(forceUpdate: Bool)
        case deactivate
        @available(macOS 12.0, *)
        case properties

        public var description: String {
            switch self {
            case let .activate(forceUpdate):
                return forceUpdate ? "activation(forceupdate)" : "activation"
            case .deactivate:
                return "deactivation"
            case .properties:
                return "properties"
            }
        }
    }

    struct Result: Sendable {
        let enabledProperty: OSSystemExtensionProperties?
    }

    enum Progress: Sendable {
        case submitting
        case needsUserApproval
        case completed
        case willCompleteAfterReboot
        case failed(Error)
        case replacingExtension(existingVersion: String, extVersion: String)
        case cancelExtension(existingVersion: String, extVersion: String)
    }
}
