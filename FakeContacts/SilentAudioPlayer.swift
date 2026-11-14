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
        var abl = audioBufferList.pointee
        for i in 0..<Int(abl.mNumberBuffers) {
            withUnsafeMutablePointer(to: &abl.mBuffers) { ptr in
                let bufferPtr = ptr.advanced(by: i).assumingMemoryBound(to: AudioBuffer.self)
                var buffer = bufferPtr.pointee
                if let data = buffer.mData {
                    let byteCount = Int(buffer.mDataByteSize)
                    data.withMemoryRebound(to: UInt8.self, capacity: byteCount) {
                        $0.initialize(repeating: 0, count: byteCount)
                    }
                }
            }
        }
        return noErr
    }

    private(set) var isPlaying = false

    func start() {
        guard !isPlaying else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: nil)
            try engine.start()
            isPlaying = true
        } catch {
            print("SilentAudioPlayer: failed to start — \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        engine.disconnectNodeInput(sourceNode)
        engine.detach(sourceNode)
        try? AVAudioSession.sharedInstance().setActive(false)
        isPlaying = false
    }
}
