// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Network
import SwiftUI
import UIKit

/// An enumeration representing the possible errors during a simulator network stream connection.
public enum StreamError: LocalizedError {
    case connectionFailed(String)
    case portUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "Network connection failed: \(reason)"
        case .portUnavailable: return "The designated port is unavailable."
        }
    }
}

/// A development-utility service responsible for receiving simulated camera frames over a local TCP connection.
/// Implements API Parity with `DeviceCameraService` to allow seamless `#if targetEnvironment(simulator)` swaps.
@MainActor
@Observable
public class CameraService {
    
    /// The most recently received frame from the network stream, serving as the live preview.
    public var livePreviewImage: UIImage? = nil
    
    /// The image captured when the user simulates taking a photo.
    public var capturedImage: UIImage? = nil
    
    /// The network port this service is configured to listen on.
    public let port: UInt16
    private let networkEngine: SimulatorNetworkEngine
    
    // MARK: - API Parity Dummy Properties
    // These properties ensure the view layer compiles flawlessly without compiler directives.
    public var flashMode: CameraFlashMode = .auto
    public var availableLenses: [VirtualLens] = []
    public var activeLens: VirtualLens? = nil
    public var currentZoomFactor: CGFloat = 1.0
    public var baseZoomFactor: CGFloat = 1.0
    
    /// Initialises the simulator camera service with a target host and port.
    /// - Parameters:
    ///   - host: The IP address of the Mac companion app (defaults to localhost "127.0.0.1").
    ///   - port: The TCP port the companion app is broadcasting on (defaults to 8080).
    public init(host: String = "127.0.0.1", port: UInt16 = 8080) {
        self.port = port
        self.networkEngine = SimulatorNetworkEngine(host: host, port: port)
        
        self.networkEngine.onImageReceived = { [weak self] image in
            Task { @MainActor [weak self] in self?.livePreviewImage = image }
        }
    }
    
    deinit {
        networkEngine.stop()
    }
    
    /// Connects to the local network stream and begins listening for video frames.
    /// - Throws: `StreamError` if the TCP socket cannot be established.
    public func startCamera() async throws {
        try await networkEngine.start()
    }
    
    /// Closes the network socket and stops listening for frames.
    public func stopCamera() {
        networkEngine.stop()
        self.livePreviewImage = nil
    }
    
    /// Simulates the action of taking a photograph by capturing the current live preview frame.
    public func takePhoto() {
        self.capturedImage = self.livePreviewImage
    }
    
    // MARK: - API Parity Dummy Actions
    // Empty implementations to satisfy the UI layer on the iOS Simulator.
    
    /// API Parity dummy implementation.
    public func toggleFlash() {}
    /// API Parity dummy implementation.
    public func switchCamera() throws {}
    /// API Parity dummy implementation.
    public func cycleLens() throws {}
    /// API Parity dummy implementation.
    public func zoom(with factor: CGFloat) throws {}
    /// API Parity dummy implementation.
    public func focus(at point: CGPoint) throws {}
}

// MARK: - Internal Network Engine

/// A thread-safe, background engine that handles raw TCP socket communication.
private final class SimulatorNetworkEngine: @unchecked Sendable {
    private var connection: NWConnection?
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.simulator.network.engine")
    
    var onImageReceived: ((UIImage) -> Void)?
    
    init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port) ?? 8080
    }
    
    func start() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let newConnection = NWConnection(host: host, port: port, using: .tcp)
            self.connection = newConnection
            
            let box = ContinuationBox(continuation)
            
            newConnection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    box.resume()
                    self?.readHeader()
                case .failed(let error):
                    box.resume(throwing: StreamError.connectionFailed(error.localizedDescription))
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        try? await self?.start()
                    }
                default:
                    break
                }
            }
            newConnection.start(queue: queue)
        }
    }
    
    func stop() {
        connection?.cancel()
        connection = nil
    }
    
    private func readHeader() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let data = data, data.count == 4, error == nil else { return }
            let length = Int(data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            self?.readPayload(length: length)
        }
    }
    
    private func readPayload(length: Int) {
        connection?.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let data = data, data.count == length, error == nil else { return }
            if let image = UIImage(data: data) {
                self?.onImageReceived?(image)
            }
            self?.readHeader()
        }
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()
    
    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }
    
    func resume() {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume()
        continuation = nil
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
