import Foundation
import AVFAudio

// MARK: - Silent Audio Player
//
// Force les boutons hardware à contrôler le volume *media* (playback) plutôt
// que le volume sonnerie, en maintenant une session audio silencieuse active.
// Ainsi l'observateur KVO sur AVAudioSession.outputVolume déclenche même quand
// le bouton Ring/Silent est sur silencieux — c'est ce qui fait marcher le peek.
final class SilentAudioPlayer: NSObject, ObservableObject {
    static let shared = SilentAudioPlayer()

    private let engine = AVAudioEngine()
    private let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in abl {
            if let data = buffer.mData {
                let byteCount = Int(buffer.mDataByteSize)
                data.withMemoryRebound(to: UInt8.self, capacity: byteCount) {
                    $0.initialize(repeating: 0, count: byteCount)
                }
            }
        }
        return noErr
    }

    private(set) var isPlaying = false

    override init() {
        super.init()
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: nil)

        // Après un appel, Siri, etc. la session peut être coupée : on la relance.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        if type == .ended {
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) { start() }
        } else {
            isPlaying = false
        }
    }

    /// Idempotent : peut être appelé à chaque retour au premier plan.
    func start() {
        if engine.isRunning {
            isPlaying = true
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isPlaying = true
        } catch {
            print("SilentAudioPlayer: failed to start — \(error)")
        }
    }

    func stop() {
        guard engine.isRunning else {
            isPlaying = false
            return
        }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isPlaying = false
    }
}
