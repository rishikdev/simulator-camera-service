//
//  SimulatorPreview.swift
//  SimulatorCameraService
//
//  Created by Rishik Dev on 11/06/26.
//

import SwiftUI

public struct SimulatorPreview: View {
    let service: SimulatorCameraService
    
    public init(service: SimulatorCameraService) {
        self.service = service
    }
    
    public var body: some View {
        GeometryReader { geometry in
            if let image = service.livePreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                ZStack {
                    Color(white: 0.15)
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Waiting for Video Stream...")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.headline)
                        Text("Ensure companion app is running on port \(service.port)")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.caption)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
