//
//  SystemExtensionRequest.swift
//  SystemExtensionkit
//
//  Created by CodingIran on 2023/9/25.
//

import os.log
import SystemExtensions

public class SystemExtensionRequest: NSObject {
    let action: SystemExtensionRequest.Action
    let bundleIdentifier: String
    let request: OSSystemExtensionRequest

    private var continuation: CheckedContinuation<SystemExtensionRequest.Result, Error>?

    private var requestUpdater: SystemExtensionRequestUpdating?

    required init(action: SystemExtensionRequest.Action, bundleIdentifier: String, request: OSSystemExtensionRequest) {
        self.action = action
        self.bundleIdentifier = bundleIdentifier
        self.request = request
        super.init()
    }

    convenience init(action: SystemExtensionRequest.Action, queue: dispatch_queue_t) throws {
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
        if #available(macOS 11.0, *) { os_log("Deinit request for \(self.request.identifier)") }
    }

    @discardableResult
    public func submit(requestUpdater: SystemExtensionRequestUpdating?) async throws -> SystemExtensionRequest.Result {
        self.requestUpdater = requestUpdater
        self.requestUpdater?.systemExtensionRequest(self, updateProgress: .submitting)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SystemExtensionRequest.Result, Error>) in
            self.continuation = nil
            self.request.delegate = self
            OSSystemExtensionManager.shared.submitRequest(self.request)
            self.continuation = cont
        }
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        switch action {
        case .activate(let forceUpdate):
            // existing
            let existingBundleIdentifier = existing.bundleIdentifier
            let existingBundleVersion = existing.bundleVersion
            let existingBundleShortVersion = existing.bundleShortVersion

            // ext
            let extBundleIdentifier = ext.bundleIdentifier
            let extBundleVersion = ext.bundleVersion
            let extBundleShortVersion = ext.bundleShortVersion

            if forceUpdate {
                requestUpdater?.systemExtensionRequest(self, updateProgress: .replacingExtension(existingVersion: existingBundleShortVersion, extVersion: extBundleShortVersion))
                return .replace
            }

            if #available(macOS 12.0, *) {
                if existing.isAwaitingUserApproval {
                    requestUpdater?.systemExtensionRequest(self, updateProgress: .replacingExtension(existingVersion: existingBundleShortVersion, extVersion: extBundleShortVersion))
                    return .replace
                }
            }

            guard existingBundleIdentifier == extBundleIdentifier,
                  existingBundleVersion == extBundleVersion,
                  existingBundleShortVersion == extBundleShortVersion
            else {
                requestUpdater?.systemExtensionRequest(self, updateProgress: .replacingExtension(existingVersion: existingBundleShortVersion, extVersion: extBundleShortVersion))
                return .replace
            }

            requestUpdater?.systemExtensionRequest(self, updateProgress: .cancelExtension(existingVersion: existingBundleShortVersion, extVersion: extBundleShortVersion))
            return .cancel
        default:
            return .cancel
        }
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        requestUpdater?.systemExtensionRequest(self, updateProgress: .needsUserApproval)
    }

    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        defer { continuation = nil }
        guard result == .completed else {
            requestUpdater?.systemExtensionRequest(self, updateProgress: .willCompleteAfterReboot)
            continuation?.resume(throwing: SystemExtensionKit.ExtensionError.extensionNeedReboot)
            return
        }
        requestUpdater?.systemExtensionRequest(self, updateProgress: .completed)
        continuation?.resume(returning: .init(enabledProperty: nil))
    }

    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        defer { continuation = nil }
        requestUpdater?.systemExtensionRequest(self, updateProgress: .failed(error))
        continuation?.resume(throwing: SystemExtensionKit.ExtensionError.extensionRequestFailed(error))
    }

    @available(macOS 12.0, *)
    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
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

public extension SystemExtensionRequest {
    enum Action {
        case activate(forceUpdate: Bool)
        case deactivate
        @available(macOS 12.0, *)
        case properties
    }

    struct Result {
        let enabledProperty: OSSystemExtensionProperties?
    }

    enum Progress {
        case submitting
        case needsUserApproval
        case completed
        case willCompleteAfterReboot
        case failed(Error)
        case replacingExtension(existingVersion: String, extVersion: String)
        case cancelExtension(existingVersion: String, extVersion: String)
    }
}
