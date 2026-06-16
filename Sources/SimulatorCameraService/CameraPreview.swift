//
//  CameraPreview.swift
//  SimulatorCameraService
//
//  Created by Rishik Dev on 11/06/26.
//

import SwiftUI

/// Initialises a declarative SwiftUI view that renders a mock camera feed over a network stream.
///
/// Designed to strictly mirror the signature of the `DeviceCameraService` equivalent.
public struct CameraPreview: View {
    public var service: CameraService
    public var executeHardwareFocus: ((CGPoint) -> Void)?
    public var updateUIFocusBox: ((CGPoint) -> Void)?
    
    /// Creates a SwiftUI view rendering the active simulated network feed.
    /// - Parameters:
    ///   - service: The active `CameraService` handling the TCP stream.
    ///   - executeHardwareFocus: An optional API Parity closure.
    ///   - updateUIFocusBox: An optional closure providing the absolute screen coordinate for UI focus overlays.
    public init(
        service: CameraService,
        executeHardwareFocus: ((CGPoint) -> Void)? = nil,
        updateUIFocusBox: ((CGPoint) -> Void)? = nil
    ) {
        self.service = service
        self.executeHardwareFocus = executeHardwareFocus
        self.updateUIFocusBox = updateUIFocusBox
    }
    
    public var body: some View {
        GeometryReader { geo in
            if let image = service.livePreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
//                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        // Send dummy focus math to keep the API perfectly identical
                        let dummyCameraPoint = CGPoint(x: 0.5, y: 0.5)
                        executeHardwareFocus?(dummyCameraPoint)
                        updateUIFocusBox?(location)
                    }
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Camera service is not running")
                    }
                    .tint(.white)
                    .foregroundStyle(.gray)
                    .padding()
                }
            }
        }
    }
}
