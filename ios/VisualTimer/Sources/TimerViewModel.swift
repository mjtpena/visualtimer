import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications

// P1-01: String rawValue for AppStorage persistence
enum ClockSize: String, CaseIterable {
    case small, medium, large

    var dimension: CGFloat {
        switch self {
        case .small: return 300
        case .medium: return 400
        case .large: return 500
        }
    }

    // P0-05: guard against missing index instead of force-unwrap
    func next() -> ClockSize {
        let all = ClockSize.allCases
        guard let idx = all.firstIndex(of: self) else { return .medium }
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
    @Published var showInput: Bool = true

    // P1-01: user preferences persisted to UserDefaults
    @Published var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode") {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    @Published var isFlipped: Bool = UserDefaults.standard.bool(forKey: "isFlipped") {
        didSet { UserDefaults.standard.set(isFlipped, forKey: "isFlipped") }
    }
    @Published private var clockSizeRaw: String =
        UserDefaults.standard.string(forKey: "clockSizeRaw") ?? ClockSize.medium.rawValue {
        didSet { UserDefaults.standard.set(clockSizeRaw, forKey: "clockSizeRaw") }
    }

    var clockSize: ClockSize {
        get { ClockSize(rawValue: clockSizeRaw) ?? .medium }
        set { clockSizeRaw = newValue.rawValue }
    }

    let audioManager = AudioManager()
    private var timer: Timer?
    private var backgroundEntryDate: Date?      // P0-03
    private var showInputWorkItem: DispatchWorkItem? // P2-03

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
        cancelShowInputDelay() // P2-03
        stopTimer()
        isRunning = false
        timeLeft = 0
        totalTime = 0
        showInput = true
    }

    func setTime() {
        let minutes = Int(inputMinutes) ?? 0
        // P0-04: if minutes == 60, force seconds to 0 to stay within 3600s
        let seconds = (minutes >= 60) ? 0 : (Int(inputSeconds) ?? 0)
        // P0-04: clamp total to 3600 seconds (60 minutes)
        let total = min(minutes * 60 + seconds, 3600)
        guard total > 0 else { return }
        timeLeft = total
        totalTime = total
        inputMinutes = ""
        inputSeconds = ""
        showInput = false
    }

    // P1-06: quick-preset support
    func setPreset(minutes: Int) {
        timeLeft = minutes * 60
        totalTime = minutes * 60
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

    // Drag-to-set: map drag position on clock face to a time value (0–3600 s)
    func handleDrag(location: CGPoint, in size: CGFloat) {
        guard !isRunning else { return }
        let cx = Double(size / 2)
        let cy = Double(size / 2)
        var dx = Double(location.x) - cx
        let dy = Double(location.y) - cy
        if isFlipped { dx = -dx }

        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 20 else { return } // ignore taps inside center hub

        var angleDeg = atan2(dy, dx) * 180 / .pi
        angleDeg = (angleDeg + 90 + 360).truncatingRemainder(dividingBy: 360)

        let newTime = max(Int((angleDeg / 360.0 * 3600).rounded()), 1)
        timeLeft = newTime
        totalTime = newTime
        showInput = false
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

    // P0-03: background drift compensation
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            guard isRunning else { return }
            backgroundEntryDate = Date()
            scheduleLocalNotification()
        case .active:
            guard let entryDate = backgroundEntryDate, isRunning else { return }
            let elapsed = Int(Date().timeIntervalSince(entryDate))
            timeLeft = max(timeLeft - elapsed, 0)
            backgroundEntryDate = nil
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            if timeLeft == 0 {
                stopTimer()
                isRunning = false
                audioManager.playTimerEnd()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                scheduleDelayedShowInput()
            }
        default:
            break
        }
    }

    // MARK: - Timer

    // P2-02: use .common RunLoop mode so timer fires during scroll/interactions
    private func startTimer() {
        scheduleLocalNotification() // P1-04
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests() // P1-04
    }

    func tick() {
        guard timeLeft > 0 else { return }
        timeLeft -= 1

        if timeLeft == 0 {
            stopTimer()
            isRunning = false
            audioManager.playTimerEnd()
            // P1-05: haptic feedback on completion
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            // P2-03: delayed transition back to input (avoids abrupt switch)
            scheduleDelayedShowInput()
        } else if timeLeft % 300 == 0 {
            // P1-03: loud tick every 5 minutes
            audioManager.playLoudTick()
        } else if timeLeft <= 10 {
            // P1-03: tick only in last 10-second countdown
            audioManager.playTick()
        }
        // else: silent
    }

    // MARK: - Helpers

    // P2-03
    private func scheduleDelayedShowInput() {
        cancelShowInputDelay()
        let workItem = DispatchWorkItem { [weak self] in
            self?.showInput = true
        }
        showInputWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func cancelShowInputDelay() {
        showInputWorkItem?.cancel()
        showInputWorkItem = nil
    }

    // P1-04
    private func scheduleLocalNotification() {
        guard timeLeft > 0 else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "VisualTimer"
        content.body = "⏰ Your timer has finished!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(timeLeft), repeats: false)
        let request = UNNotificationRequest(
            identifier: "timer-end", content: content, trigger: trigger)
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Notification scheduling error: \(error)")
            }
        }
    }
}
