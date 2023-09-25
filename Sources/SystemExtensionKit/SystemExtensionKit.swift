//
//  SystemExtensionKit.swift
//  SystemExtensionKit
//
//  Created by CodingIran on 2023/2/9.
//

import SystemExtensions

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.5)
#error("SystemExtensionKit doesn't support Swift versions below 5.5.")
#endif

/// Current SystemExtensionKit version 2.0.0. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
public let version = "2.0.0"

public let SystemExtension = SystemExtensionKit.shared

public protocol SystemExtensionRequestUpdating: NSObjectProtocol {
    func systemExtensionRequest(_ request: SystemExtensionRequest, updateProgress progress: SystemExtensionRequest.Progress)
}

public class SystemExtensionKit: NSObject {
    public static let shared = SystemExtensionKit()
    override private init() {}

    static let requestQueue = DispatchQueue(label: "com.systemExtensionkit.request.queue")

    public weak var requestUpdater: SystemExtensionRequestUpdating?

    private var outstandingRequests: Set<SystemExtensionRequest> = []

    public func activeSystemExtension(forceUpdate: Bool = false) async throws {
        let activationRequest = try SystemExtensionRequest(action: .activate(forceUpdate: forceUpdate), queue: Self.requestQueue)
        try await submitRequest(activationRequest)
    }

    public func deactiveSystemExtension() async throws {
        let activationRequest = try SystemExtensionRequest(action: .deactivate, queue: Self.requestQueue)
        try await submitRequest(activationRequest)
    }

    @available(macOS 12.0, *)
    public func enabledSystemExtensionProperty() async throws -> OSSystemExtensionProperties? {
        let propertiesRequest = try SystemExtensionRequest(action: .properties, queue: Self.requestQueue)
        let properties = try await submitRequest(propertiesRequest).enabledProperty
        return properties
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

    @discardableResult
    private func submitRequest(_ request: SystemExtensionRequest) async throws -> SystemExtensionRequest.Result {
        outstandingRequests.insert(request)
        defer {
            outstandingRequests.remove(request)
        }
        let result = try await request.submit(requestUpdater: requestUpdater)
        return result
    }
}
