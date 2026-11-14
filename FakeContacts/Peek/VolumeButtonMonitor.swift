import AVFoundation
import Combine
import Foundation

// MARK: - Volume button monitor

/// Observes media volume changes while the contacts list is visible. It does
/// not reset or force the system volume: pressing a volume button triggers one
/// callback and leaves the user's volume control intact.
final class VolumeButtonMonitor: ObservableObject {
    var onPress: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var routeObserver: NSObjectProtocol?
    private var lastVolume: Float = -1
    private var lastTriggerTime: TimeInterval = 0
    private var ignoreChangesUntil: TimeInterval = 0
    private var isMonitoring = false

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        SilentAudioPlayer.shared.start()
        lastVolume = session.outputVolume
        ignoreChangesUntil = Date.timeIntervalSinceReferenceDate + 0.4

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] session, _ in
            let volume = session.outputVolume
            DispatchQueue.main.async {
                self?.handleVolumeChange(volume)
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.handleRouteChange()
        }
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        observation?.invalidate()
        observation = nil
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        SilentAudioPlayer.shared.stop()
        onPress = nil
    }

    private func handleVolumeChange(_ volume: Float) {
        guard isMonitoring else { return }

        let previous = lastVolume
        lastVolume = volume
        guard abs(volume - previous) > 0.001 else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard now >= ignoreChangesUntil,
              now - lastTriggerTime > 0.35 else {
            return
        }

        lastTriggerTime = now
        onPress?()
    }

    private func handleRouteChange() {
        lastVolume = session.outputVolume
        ignoreChangesUntil = Date.timeIntervalSinceReferenceDate + 0.5
    }
}
