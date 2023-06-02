<p align="center">
  <br />
  <img src=https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242794221-fa956d07-04fa-4ab7-af94-61ced3948dd9.png alt="logo" height="100px" />
  <h3 style="font-size:26" align="center">Concurrency Wrapper for SystemExtension API</h3>
  <br />
</p>

<p align="center">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797256-a265a02c-5db9-4795-a94a-e2f2ffa7f136.svg" alt="SwiftPM Compatible">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797253-dd4f20e6-67a5-4594-a29e-d3f668e3281f.svg" alt="Cocoapods Compatible">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797257-2b6fd077-4815-4ac9-bcaa-e55c5905e7fc.svg" alt="macOS Versions Supported">
  <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/11780294/242797251-4f5272cd-1b3d-470d-b88a-3dc2e3dbb879.svg" alt="MIT License">
</p>

----------------


# SystemExtensionKit

macOS platform utils for [SystemExtension](https://developer.apple.com/documentation/systemextensions)

## Install

### SwiftPM

```
https://github.com/codingiran/SystemExtensionKit.git
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
