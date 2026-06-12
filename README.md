# SimulatorCameraService

A development-utility package for mocking hardware camera inputs in the iOS Simulator. 

Testing camera-dependent SwiftUI applications on the simulator usually results in a blank screen. This package solves that by streaming a live video feed from a local macOS companion app via local network sockets directly into your SwiftUI preview.

## Features

* **API Parity for Clean Code:** Shares the exact same method signatures, properties, and dummy types as [`DeviceCameraService`](https://github.com/rishikdev/device-camera-service.git). This ensures your view layer compiles seamlessly across both the simulator and physical devices without littering your UI code with compiler directives.
* **Modern Lifecycle Management:** Spin up connections using `async/await` and tear them down synchronously to prevent port hogging on your local machine.

## Installation

Add this package to your project using Swift Package Manager.

In Xcode:
1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/rishikdev/simulator-camera-service.git`
3. Choose the dependency rule (e.g., Up to Next Major Version).

## Unified Usage Example

By importing `SimulatorCameraService` alongside `DeviceCameraService`, you can write a single, unified view. The compiler will automatically route to the network stream on your Mac or the physical AVFoundation pipeline on an iPhone.

```swift
import SwiftUI

// Conditional Imports
#if targetEnvironment(simulator)
import SimulatorCameraService
#else
import DeviceCameraService
#endif

struct UnifiedCameraView: View {
    
    // Conditional Instantiation
    #if targetEnvironment(simulator)
    @State private var camera = CameraService(host: "127.0.0.1", port: 8080)
    #else
    @State private var camera = CameraService()
    #endif
    
    var body: some View {
        ZStack {
            CameraPreview(
                service: camera,
                executeHardwareFocus: { cameraPoint in
                    try? camera.focus(at: cameraPoint)
                },
                updateUIFocusBox: { viewPoint in
                    // Trigger custom UI focus animations
                }
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                Button("Take Photo") {
                    camera.takePhoto()
                }
                .padding()
            }
        }
        .task {
            try? await camera.startCamera()
        }
        .onDisappear {
            // Automatically closes network ports (Simulator) 
            // or powers down optical sensors (Device)
            camera.stopCamera()
        }
    }
}
