import AppKit
import Foundation

@Observable
class SafetyTimeoutManager {
    private var checkTimer: Timer?
    private var lastMousePosition: CGPoint = .zero
    private var lastMovementTime: Date = Date()
    private let timeoutInterval: TimeInterval = 10.0
    private let checkInterval: TimeInterval = 0.5

    var onSafetyTimeout: (() -> Void)?

    func startMonitoring() {
        lastMousePosition = NSEvent.mouseLocation
        lastMovementTime = Date()

        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkMouseMovement()
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func resetTimer() {
        lastMovementTime = Date()
        lastMousePosition = NSEvent.mouseLocation
    }

    private func checkMouseMovement() {
        let currentPosition = NSEvent.mouseLocation

        if currentPosition != lastMousePosition {
            lastMousePosition = currentPosition
            lastMovementTime = Date()
        } else if Date().timeIntervalSince(lastMovementTime) >= timeoutInterval {
            onSafetyTimeout?()
            stopMonitoring()
        }
    }
}
