import Foundation
import AVFAudio
import AVFoundation

// MARK: - Silent Audio Player
//
// Forces the hardware volume buttons to control the *media/playback* volume
// instead of the ringer volume by keeping a silent audio session active.
// This makes `AVAudioSession.outputVolume` KVO fire reliably even when the
// Ring/Silent switch is set to silent, which is what the volume-button "peek"
// trick relies on.
final class SilentAudioPlayer: NSObject, ObservableObject {
    static let shared = SilentAudioPlayer()

    private let engine = AVAudioEngine()
    private let silentSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in abl {
            if let data = buffer.mData {
                let byteCount = Int(buffer.mDataByteSize)
                data.withMemoryRebound(to: UInt8.self, capacity: byteCount) { ptr in
                    ptr.initialize(repeating: 0, count: byteCount)
                }
            }
        }
        return noErr
    }

    private(set) var isPlaying = false

    override init() {
        super.init()
    }

    func start() {
        guard !isPlaying else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            engine.attach(silentSource)
            engine.connect(silentSource, to: engine.mainMixerNode, format: nil)
            try engine.start()
            isPlaying = true
        } catch {
            print("SilentAudioPlayer: failed to start — \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        engine.disconnectNodeInput(silentSource)
        engine.detach(silentSource)
        try? AVAudioSession.sharedInstance().setActive(false)
        isPlaying = false
    }
}
