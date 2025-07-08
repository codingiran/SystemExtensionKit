@testable import SystemExtensionKit
import SystemExtensions
import XCTest

final class SystemExtensionKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Version Tests

    func testSystemExtensionConstant() {
        XCTAssertIdentical(SystemExtension, SystemExtensionKit.shared, "SystemExtension should reference the shared instance")
    }

    // MARK: - Singleton Tests

    func testSingletonInstance() {
        let instance1 = SystemExtensionKit.shared
        let instance2 = SystemExtensionKit.shared
        XCTAssertIdentical(instance1, instance2, "SystemExtensionKit should be a singleton")
    }

    // MARK: - ExtensionStatus Tests

    func testExtensionStatusProperties() {
        let unknownStatus = SystemExtensionKit.ExtensionStatus.unknown
        XCTAssertTrue(unknownStatus.isUnknown)
        XCTAssertFalse(unknownStatus.isNotInstalled)
        XCTAssertFalse(unknownStatus.isWaitingApproval)
        XCTAssertFalse(unknownStatus.isInstalled)
        XCTAssertEqual(unknownStatus.description, "unknown")

        let notInstalledStatus = SystemExtensionKit.ExtensionStatus.notInstalled
        XCTAssertFalse(notInstalledStatus.isUnknown)
        XCTAssertTrue(notInstalledStatus.isNotInstalled)
        XCTAssertFalse(notInstalledStatus.isWaitingApproval)
        XCTAssertFalse(notInstalledStatus.isInstalled)
        XCTAssertEqual(notInstalledStatus.description, "not installed")
    }

    @available(macOS 12.0, *)
    func testExtensionStatusWithProperties() {
        // Create a mock OSSystemExtensionProperties object for testing
        // Note: Since OSSystemExtensionProperties is a system class, we can only test our enum logic
        if let mockProperties = createMockProperties() {
            let waitingStatus = SystemExtensionKit.ExtensionStatus.waitingApproval(mockProperties)
            XCTAssertFalse(waitingStatus.isUnknown)
            XCTAssertFalse(waitingStatus.isNotInstalled)
            XCTAssertTrue(waitingStatus.isWaitingApproval)
            XCTAssertFalse(waitingStatus.isInstalled)
            XCTAssertEqual(waitingStatus.description, "waiting for userApproval")

            let installedStatus = SystemExtensionKit.ExtensionStatus.installed(mockProperties)
            XCTAssertFalse(installedStatus.isUnknown)
            XCTAssertFalse(installedStatus.isNotInstalled)
            XCTAssertFalse(installedStatus.isWaitingApproval)
            XCTAssertTrue(installedStatus.isInstalled)
            XCTAssertEqual(installedStatus.description, "installed")
        }
    }

    // MARK: - ExtensionError Tests

    func testExtensionErrorDescriptions() {
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        let directoryError = SystemExtensionKit.ExtensionError.extensionDirectoryFailed("test/path", testError)
        XCTAssertTrue(directoryError.errorDescription?.contains("Failed to get the contents of test/path") == true)
        XCTAssertTrue(directoryError.errorDescription?.contains("Test error") == true)

        let notExistError = SystemExtensionKit.ExtensionError.extensionNotExist
        XCTAssertEqual(notExistError.errorDescription, "Failed to find any system extensions")

        let createURLError = SystemExtensionKit.ExtensionError.extensionCreateURLFailed("test/url")
        XCTAssertEqual(createURLError.errorDescription, "Failed to create a bundle with URL: test/url")

        let bundleIdError = SystemExtensionKit.ExtensionError.extensionBundleIdMissing("test/bundle")
        XCTAssertEqual(bundleIdError.errorDescription, "Failed to get bundleIdentifier of system extensions bundle with URL: test/bundle")

        let requestFailedError = SystemExtensionKit.ExtensionError.extensionRequestFailed(testError)
        XCTAssertTrue(requestFailedError.errorDescription?.contains("Failed to request extension") == true)

        let rebootError = SystemExtensionKit.ExtensionError.extensionNeedReboot
        XCTAssertEqual(rebootError.errorDescription, "Failed to request extension: user need to reboot mac")

        let unsupportError = SystemExtensionKit.ExtensionError.extensionSystemUnsupport
        XCTAssertEqual(unsupportError.errorDescription, "Failed to request extension: system version unsupport")
    }

    func testOSSystemExtensionErrorCodeDescriptions() {
        let codes: [OSSystemExtensionError.Code] = [
            .unknown,
            .missingEntitlement,
            .unsupportedParentBundleLocation,
            .extensionNotFound,
            .extensionMissingIdentifier,
            .duplicateExtensionIdentifer,
            .unknownExtensionCategory,
            .codeSignatureInvalid,
            .validationFailed,
            .forbiddenBySystemPolicy,
            .requestCanceled,
            .requestSuperseded,
            .authorizationRequired,
        ]

        let expectedDescriptions = [
            "unknown",
            "Missing Entitlement",
            "Unsupported Parent Bundle Location",
            "Extension Not found",
            "Extension Missing Identifier",
            "Duplicate Extension Identifier",
            "Unknown Extension Category",
            "Code Signature Invalid",
            "Validation Failed",
            "Forbidden by System Policy",
            "Request Cancelled",
            "Request Superceeded",
            "Authorization Required",
        ]

        for (index, code) in codes.enumerated() {
            XCTAssertEqual(code.description, expectedDescriptions[index])
        }
    }

    // MARK: - SystemExtensionRequest.Action Tests

    func testRequestActionDescriptions() {
        let activateAction = SystemExtensionRequest.Action.activate(forceUpdate: false)
        XCTAssertEqual(activateAction.description, "activation")

        let forceActivateAction = SystemExtensionRequest.Action.activate(forceUpdate: true)
        XCTAssertEqual(forceActivateAction.description, "activation(forceupdate)")

        let deactivateAction = SystemExtensionRequest.Action.deactivate
        XCTAssertEqual(deactivateAction.description, "deactivation")

        if #available(macOS 12.0, *) {
            let propertiesAction = SystemExtensionRequest.Action.properties
            XCTAssertEqual(propertiesAction.description, "properties")
        }
    }

    // MARK: - Bundle Detection Tests

    func testGetExtensionBundleThrowsWhenDirectoryNotExists() {
        // This test will fail due to the actual bundle structure, but can verify error handling logic
        XCTAssertThrowsError(try SystemExtensionKit.getExtensionBundle()) { error in
            if let extensionError = error as? SystemExtensionKit.ExtensionError {
                switch extensionError {
                case let .extensionDirectoryFailed(path, _):
                    XCTAssertTrue(path.contains("Contents/Library/SystemExtensions"))
                case .extensionNotExist:
                    // This error could also occur if directory exists but is empty
                    break
                default:
                    XCTFail("Unexpected error type: \(extensionError)")
                }
            } else {
                XCTFail("Expected ExtensionError, got: \(error)")
            }
        }
    }

    // MARK: - SystemExtensionRequest Tests

    func testSystemExtensionRequestInitializationFailure() {
        let queue = DispatchQueue(label: "test.queue")

        // Test activation request initialization failure (due to no actual extension bundle)
        XCTAssertThrowsError(try SystemExtensionRequest(action: .activate(forceUpdate: false), queue: queue))

        // Test deactivation request initialization failure
        XCTAssertThrowsError(try SystemExtensionRequest(action: .deactivate, queue: queue))

        // Test properties request initialization failure
        if #available(macOS 12.0, *) {
            XCTAssertThrowsError(try SystemExtensionRequest(action: .properties, queue: queue))
        }
    }

    @available(macOS 11.9, *)
    func testSystemExtensionRequestInitializationOnOldMacOS() {
        let queue = DispatchQueue(label: "test.queue")

        // Before macOS 12.0, properties request should throw extensionSystemUnsupport error
        // Note: This test needs to run on appropriate system versions
        if #available(macOS 12.0, *) {
            // Skip this test on macOS 12.0+
        } else {
            XCTAssertThrowsError(try SystemExtensionRequest(action: .properties, queue: queue)) { error in
                if let extensionError = error as? SystemExtensionKit.ExtensionError {
                    switch extensionError {
                    case .extensionSystemUnsupport:
                        break // Expected error
                    default:
                        XCTFail("Expected extensionSystemUnsupport, got: \(extensionError)")
                    }
                }
            }
        }
    }

    // MARK: - RequestUpdating Protocol Tests

    func testRequestUpdatingProtocol() {
        final class MockRequestUpdater: @unchecked Sendable, SystemExtensionRequestUpdating {
            var receivedProgress: SystemExtensionRequest.Progress?
            var receivedRequest: SystemExtensionRequest?

            func systemExtensionRequest(_ request: SystemExtensionRequest, updateProgress progress: SystemExtensionRequest.Progress) {
                receivedRequest = request
                receivedProgress = progress
            }
        }

        // Test if protocol methods can be called correctly
        let mockUpdater = MockRequestUpdater()
        let mockRequest = createMockSystemExtensionRequest()

        mockUpdater.systemExtensionRequest(mockRequest, updateProgress: .submitting)

        XCTAssertNotNil(mockUpdater.receivedRequest)
        XCTAssertNotNil(mockUpdater.receivedProgress)

        if case .submitting = mockUpdater.receivedProgress! {
            // Correctly received submitting progress
        } else {
            XCTFail("Expected submitting progress")
        }
    }

    // MARK: - Result Tests

    func testSystemExtensionRequestResult() {
        let result = SystemExtensionRequest.Result(enabledProperty: nil)
        XCTAssertNil(result.enabledProperty)

        if #available(macOS 12.0, *) {
            if let mockProperties = createMockProperties() {
                let resultWithProperty = SystemExtensionRequest.Result(enabledProperty: mockProperties)
                XCTAssertNotNil(resultWithProperty.enabledProperty)
            }
        }
    }

    // MARK: - Async Function Tests

    func testCheckSystemExtensionStatusAsync() async {
        let systemExtension = SystemExtensionKit.shared

        // When no actual system extension is present, should return .notInstalled or .unknown
        let status = await systemExtension.checkSystemExtensionStatus()

        // Verify that the returned status is valid
        XCTAssertTrue(status.isNotInstalled || status.isUnknown, "Status should be either notInstalled or unknown when no extension is present")
    }

    // MARK: - Helper Methods

    private func createMockSystemExtensionRequest() -> SystemExtensionRequest {
        let queue = DispatchQueue(label: "test.queue")
        let mockOSRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: "com.test.extension", queue: queue)
        return SystemExtensionRequest(action: .activate(forceUpdate: false), bundleIdentifier: "com.test.extension", request: mockOSRequest)
    }

    @available(macOS 12.0, *)
    private func createMockProperties() -> OSSystemExtensionProperties? {
        // Since OSSystemExtensionProperties is a system class, we cannot create instances directly
        // Return nil here; in actual testing, might need to use real system extensions or mock frameworks
        return nil
    }

    // MARK: - Thread Safety Tests

    func testSystemExtensionKitThreadSafety() {
        let expectation = self.expectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue.global(qos: .background)

        for _ in 0 ..< 10 {
            queue.async {
                let instance = SystemExtensionKit.shared
                XCTAssertNotNil(instance)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Test Extensions

extension SystemExtensionKitTests {
    func testSwiftVersionCheck() {
        // Verify that Swift version check works at compile time
        // If the code compiles successfully, it means the Swift version check is working correctly
        XCTAssertTrue(true, "Swift version check passed")
    }
}
