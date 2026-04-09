import AVFoundation

@MainActor
final class AudioManager: ObservableObject {
    private var tickPlayer: AVAudioPlayer?
    private var loudTickPlayer: AVAudioPlayer?
    private var timerEndPlayer: AVAudioPlayer?

    @Published var isSoundOn: Bool = true

    func loadSounds() {
        tickPlayer = loadSound(named: "tick", ext: "wav")
        loudTickPlayer = loadSound(named: "loud-tick", ext: "wav")
        timerEndPlayer = loadSound(named: "timer", ext: "wav")
    }

    private func loadSound(named name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Sound file \(name).\(ext) not found")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Error loading \(name).\(ext): \(error)")
            return nil
        }
    }

    func playTick() {
        guard isSoundOn else { return }
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
    }

    func playLoudTick() {
        guard isSoundOn else { return }
        loudTickPlayer?.currentTime = 0
        loudTickPlayer?.play()
    }

    func playTimerEnd() {
        guard isSoundOn else { return }
        timerEndPlayer?.currentTime = 0
        timerEndPlayer?.play()
    }

    func toggleSound() {
        isSoundOn.toggle()
    }
}
