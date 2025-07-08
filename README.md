<p align="center">
  <br />
  <img src=https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242794221-fa956d07-04fa-4ab7-af94-61ced3948dd9.png alt="logo" height="100px" />
  <h3 style="font-size:26" align="center">Modern Swift Wrapper for SystemExtensions API</h3>
  <br />
</p>

<p align="center">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797256-a265a02c-5db9-4795-a94a-e2f2ffa7f136.svg" alt="SwiftPM Compatible">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797253-dd4f20e6-67a5-4594-a29e-d3f668e3281f.svg" alt="Cocoapods Compatible">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797257-2b6fd077-4815-4ac9-bcaa-e55c5905e7fc.svg" alt="macOS Versions Supported">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797251-4f5272cd-1b3d-470d-b88a-3dc2e3dbb879.svg" alt="MIT License">
</p>

# SystemExtensionKit

A modern Swift wrapper for Apple's [SystemExtensions framework](https://developer.apple.com/documentation/systemextensions) that provides async/await support and simplified APIs for managing system extensions on macOS.

## Features

- 🔄 **Async/await support** - Modern Swift concurrency
- 📱 **Simple API** - Easy-to-use methods for common tasks
- 🛡️ **Error handling** - Comprehensive error types and descriptions
- 📊 **Progress tracking** - Real-time status updates
- 🎯 **Swift 5.10+** - Built for modern Swift
- 📦 **SwiftPM** - Multiple installation options

## Requirements

- macOS 10.15+
- Swift 5.10+
- Xcode 14.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/codingiran/SystemExtensionKit.git", from: "2.1.0")
]
```

## Quick Start

### Basic Usage

```swift
import SystemExtensionKit

// Activate system extension
do {
    try await SystemExtension.activeSystemExtension()
    print("Extension activated successfully")
} catch {
    print("Failed to activate: \(error.localizedDescription)")
}

// Check extension status
let status = await SystemExtension.checkSystemExtensionStatus()
switch status {
case .installed:
    print("Extension is installed and running")
case .waitingApproval:
    print("Extension needs user approval")
case .notInstalled:
    print("Extension is not installed")
case .unknown:
    print("Status unknown (macOS < 12.0)")
}

// Deactivate system extension
do {
    try await SystemExtension.deactiveSystemExtension()
    print("Extension deactivated successfully")
} catch {
    print("Failed to deactivate: \(error.localizedDescription)")
}
```

### Progress Monitoring

```swift
class ExtensionManager: SystemExtensionRequestUpdating {
    
    func setupExtension() {
        // Set progress updater
        SystemExtension.requestUpdater = self
        
        Task {
            do {
                try await SystemExtension.activeSystemExtension()
            } catch {
                print("Extension activation failed: \(error)")
            }
        }
    }
    
    // MARK: - SystemExtensionRequestUpdating
    
    func systemExtensionRequest(_ request: SystemExtensionRequest, updateProgress progress: SystemExtensionRequest.Progress) {
        switch progress {
        case .submitting:
            print("Submitting extension request...")
        case .needsUserApproval:
            print("User approval required")
        case .completed:
            print("Extension request completed")
        case .willCompleteAfterReboot:
            print("Restart required to complete")
        case .failed(let error):
            print("Request failed: \(error.localizedDescription)")
        case .replacingExtension(let existing, let new):
            print("Replacing version \(existing) with \(new)")
        case .cancelExtension(let existing, let new):
            print("Canceling replacement of \(existing) with \(new)")
        }
    }
}
```

### Advanced Usage

```swift
// Force update extension
try await SystemExtension.activeSystemExtension(forceUpdate: true)

// Get extension properties (macOS 12.0+)
if #available(macOS 12.0, *) {
    if let properties = try await SystemExtension.enabledSystemExtensionProperty() {
        print("Bundle ID: \(properties.bundleIdentifier)")
        print("Version: \(properties.bundleVersion)")
        print("Awaiting approval: \(properties.isAwaitingUserApproval)")
    }
}
```

## Error Handling

SystemExtensionKit provides comprehensive error types:

```swift
do {
    try await SystemExtension.activeSystemExtension()
} catch SystemExtensionKit.ExtensionError.extensionNotExist {
    print("No system extension found in app bundle")
} catch SystemExtensionKit.ExtensionError.extensionNeedReboot {
    print("System restart required")
} catch SystemExtensionKit.ExtensionError.extensionSystemUnsupport {
    print("System version not supported")
} catch {
    print("Other error: \(error.localizedDescription)")
}
```

## License

SystemExtensionKit is available under the MIT license. See the LICENSE file for more info.
