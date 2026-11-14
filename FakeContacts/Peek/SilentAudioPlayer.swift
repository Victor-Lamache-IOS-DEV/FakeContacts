import AVFoundation
import Foundation

// MARK: - Silent audio session
//
// Keeps the app's audio session active so the hardware volume buttons adjust
// media volume (instead of ring volume). No audible sound is produced and no
// other audio is interrupted.

final class SilentAudioPlayer {
    static let shared = SilentAudioPlayer()

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var wantsRunning = false

    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // MARK: Public API

    func start() {
        wantsRunning = true
        configureAndStart()
    }

    func stop() {
        wantsRunning = false
        stopEngine()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: Engine

    private func configureAndStart() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        if engine?.isRunning == true { return }

        stopEngine()

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return }
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let byteCount = Int(buffer.mDataByteSize)
                data.withMemoryRebound(to: UInt8.self, capacity: byteCount) {
                    $0.initialize(repeating: 0, count: byteCount)
                }
            }
            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
        engine.prepare()

        do {
            try engine.start()
            self.engine = engine
            self.sourceNode = source
        } catch {
            engine.stop()
        }
    }

    private func stopEngine() {
        engine?.stop()
        if let engine, let sourceNode {
            engine.detach(sourceNode)
        }
        engine = nil
        sourceNode = nil
    }

    private func restartIfNeeded() {
        guard wantsRunning else { return }
        stopEngine()
        configureAndStart()
    }

    // MARK: Notifications

    @objc private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            stopEngine()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume) {
                DispatchQueue.main.async { [weak self] in
                    self?.restartIfNeeded()
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.restartIfNeeded()
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard wantsRunning,
              let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.restartIfNeeded()
        }
    }
}
