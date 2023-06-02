# SystemExtensionKit

macOS platform utils for [SystemExtension](https://developer.apple.com/documentation/systemextensions)

## Install

### SwiftPM

```
<https://github.com/codingiran/SystemExtensionKit.git>
```

### Cocoapods

```
pod 'SystemExtensionKit'
```

## Examples

```swift
// Import
#if canImport(SystemExtensionKit)
import SystemExtensionKit
#endif

...

// check SystemExtension Status
if #available(macOS 12.0, *) {
    let enable = await SystemExtension.checkSystemExtensionEnableStatus()
    if enable {
        debugPrint("Enabled SystemExtension already exist")
    } else {
        debugPrint("SystemExtension is not enabled")
    }
    return !enable
}

// Active SystemExtension
do {
    try await SystemExtension.activeSystemExtension()
} catch {
		// Handle error
    debugPrint(error.localizedDescription)
}

// Delegate Method
SystemExtension.delegate = self

// MARK: - SystemExtensionDelegate

func systemExtensionKit(_ systemExtension: SystemExtensionKit, requestResult: SystemExtensionKit.RequestResult) {
    switch requestResult {
    case .completed(let request):
        debugPrint("SystemExtension: \(request.identifier) did finish request, user authorized")
    case .willCompleteAfterReboot(let request):
        debugPrint("SystemExtension: \(request.identifier) did finish request, but need user reboot mac")
    case .failed(let request, let error):
        debugPrint("SystemExtension: \(request.identifier) request failed: \(error.localizedDescription)")
    case .needsUserApproval(let request):
        debugPrint("SystemExtension: \(request.identifier) requires user approval")
    case .replacingExtension(let request, let existingVersion, let extensionVersion):
        debugPrint("SystemExtension replacing extension \(request.identifier) version \(existingVersion) with version \(extensionVersion)")
    }
}
```
