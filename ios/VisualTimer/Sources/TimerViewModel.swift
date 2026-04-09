import Foundation
import Combine

enum ClockSize: CaseIterable {
    case small, medium, large

    var dimension: CGFloat {
        switch self {
        case .small: return 300
        case .medium: return 400
        case .large: return 500
        }
    }

    func next() -> ClockSize {
        let all = ClockSize.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

@MainActor
final class TimerViewModel: ObservableObject {
    @Published var timeLeft: Int = 0
    @Published var totalTime: Int = 0
    @Published var isRunning: Bool = false
    @Published var inputMinutes: String = ""
    @Published var inputSeconds: String = ""
    @Published var isDarkMode: Bool = false
    @Published var showInput: Bool = true
    @Published var clockSize: ClockSize = .medium
    @Published var isFlipped: Bool = false

    let audioManager = AudioManager()
    private var timer: Timer?

    var clockDimension: CGFloat { clockSize.dimension }
    var timerRadius: CGFloat { clockDimension / 2 - 20 }
    let borderWidth: CGFloat = 8

    func startStop() {
        guard timeLeft > 0 else { return }
        isRunning.toggle()
        showInput = false
        if isRunning {
            startTimer()
        } else {
            stopTimer()
        }
    }

    func reset() {
        stopTimer()
        isRunning = false
        timeLeft = 0
        totalTime = 0
        showInput = true
    }

    func setTime() {
        let minutes = Int(inputMinutes) ?? 0
        let seconds = Int(inputSeconds) ?? 0
        let total = minutes * 60 + seconds
        guard total > 0 else { return }
        timeLeft = total
        totalTime = total
        inputMinutes = ""
        inputSeconds = ""
        showInput = false
    }

    func handleInputChange(_ text: String, isMinutes: Bool) {
        let numeric = text.filter(\.isNumber)
        if isMinutes {
            if numeric.isEmpty || (Int(numeric) ?? 0) <= 60 {
                inputMinutes = numeric
            }
        } else {
            if numeric.isEmpty || (Int(numeric) ?? 0) < 60 {
                inputSeconds = numeric
            }
        }
    }

    func toggleClockSize() {
        clockSize = clockSize.next()
    }

    func toggleFlip() {
        isFlipped.toggle()
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
    }

    func formattedTime() -> String {
        let mins = timeLeft / 60
        let secs = timeLeft % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard timeLeft > 0 else { return }
        timeLeft -= 1

        if timeLeft == 0 {
            stopTimer()
            isRunning = false
            showInput = true
            audioManager.playTimerEnd()
        } else if timeLeft % 300 == 0 {
            audioManager.playLoudTick()
        } else {
            audioManager.playTick()
        }
    }
}
