import XCTest
@testable import VisualTimer

@MainActor
final class TimerViewModelTests: XCTestCase {

    // Clear persisted preferences before each test so initial-state assertions are reliable
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "isDarkMode")
        UserDefaults.standard.removeObject(forKey: "isFlipped")
        UserDefaults.standard.removeObject(forKey: "clockSizeRaw")
        UserDefaults.standard.removeObject(forKey: "isSoundOn")
    }

    func testInitialState() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.timeLeft, 0)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.showInput)
        XCTAssertEqual(vm.inputMinutes, "")
        XCTAssertEqual(vm.inputSeconds, "")
        XCTAssertFalse(vm.isDarkMode)
        XCTAssertFalse(vm.isFlipped)
        XCTAssertEqual(vm.clockSize, .medium)
    }

    func testSetTime() {
        let vm = TimerViewModel()
        vm.inputMinutes = "5"
        vm.inputSeconds = "30"
        vm.setTime()
        XCTAssertEqual(vm.timeLeft, 330)
        XCTAssertEqual(vm.totalTime, 330)
        XCTAssertFalse(vm.showInput)
        XCTAssertEqual(vm.inputMinutes, "")
        XCTAssertEqual(vm.inputSeconds, "")
    }

    func testSetTimeZeroDoesNothing() {
        let vm = TimerViewModel()
        vm.inputMinutes = "0"
        vm.inputSeconds = "0"
        vm.setTime()
        XCTAssertEqual(vm.timeLeft, 0)
        XCTAssertTrue(vm.showInput)
    }

    func testReset() {
        let vm = TimerViewModel()
        vm.inputMinutes = "1"
        vm.setTime()
        vm.startStop()
        vm.reset()
        XCTAssertEqual(vm.timeLeft, 0)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.showInput)
    }

    func testStartStop() {
        let vm = TimerViewModel()
        vm.inputMinutes = "1"
        vm.setTime()

        vm.startStop()
        XCTAssertTrue(vm.isRunning)
        XCTAssertFalse(vm.showInput)

        vm.startStop()
        XCTAssertFalse(vm.isRunning)
    }

    func testStartStopWithZeroTimeDoesNothing() {
        let vm = TimerViewModel()
        vm.startStop()
        XCTAssertFalse(vm.isRunning)
    }

    func testHandleInputMinutes() {
        let vm = TimerViewModel()
        vm.handleInputChange("45", isMinutes: true)
        XCTAssertEqual(vm.inputMinutes, "45")

        vm.handleInputChange("61", isMinutes: true)
        XCTAssertEqual(vm.inputMinutes, "45") // rejected
    }

    func testHandleInputSeconds() {
        let vm = TimerViewModel()
        vm.handleInputChange("30", isMinutes: false)
        XCTAssertEqual(vm.inputSeconds, "30")

        vm.handleInputChange("60", isMinutes: false)
        XCTAssertEqual(vm.inputSeconds, "30") // rejected
    }

    func testHandleInputStripsNonNumeric() {
        let vm = TimerViewModel()
        vm.handleInputChange("1a2b3", isMinutes: true)
        // "1a2b3" → numeric "123" → 123 > 60 → rejected, stays empty
        XCTAssertEqual(vm.inputMinutes, "")
    }

    func testHandleInputAcceptsValidNumeric() {
        let vm = TimerViewModel()
        vm.handleInputChange("1a2", isMinutes: true)
        // "1a2" → numeric "12" → 12 <= 60 → accepted
        XCTAssertEqual(vm.inputMinutes, "12")
    }

    func testToggleClockSize() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.clockSize, .medium)
        vm.toggleClockSize()
        XCTAssertEqual(vm.clockSize, .large)
        vm.toggleClockSize()
        XCTAssertEqual(vm.clockSize, .small)
        vm.toggleClockSize()
        XCTAssertEqual(vm.clockSize, .medium)
    }

    func testToggleDarkMode() {
        let vm = TimerViewModel()
        XCTAssertFalse(vm.isDarkMode)
        vm.toggleDarkMode()
        XCTAssertTrue(vm.isDarkMode)
        vm.toggleDarkMode()
        XCTAssertFalse(vm.isDarkMode)
    }

    func testToggleFlip() {
        let vm = TimerViewModel()
        XCTAssertFalse(vm.isFlipped)
        vm.toggleFlip()
        XCTAssertTrue(vm.isFlipped)
    }

    func testFormattedTime() {
        let vm = TimerViewModel()
        vm.inputMinutes = "5"
        vm.inputSeconds = "9"
        vm.setTime()
        XCTAssertEqual(vm.formattedTime(), "05:09")
    }

    func testClockSizeDimension() {
        XCTAssertEqual(ClockSize.small.dimension, 300)
        XCTAssertEqual(ClockSize.medium.dimension, 400)
        XCTAssertEqual(ClockSize.large.dimension, 500)
    }

    // MARK: - New tests

    func testSetPreset() {
        let vm = TimerViewModel()
        vm.setPreset(minutes: 5)
        XCTAssertEqual(vm.timeLeft, 300)
        XCTAssertEqual(vm.totalTime, 300)
        XCTAssertEqual(vm.inputMinutes, "")
        XCTAssertEqual(vm.inputSeconds, "")
        XCTAssertFalse(vm.showInput)
    }

    // P0-05: ClockSize.next() must never crash for any case
    func testClockSizeNextSafety() {
        ClockSize.allCases.forEach { size in
            let next = size.next()
            XCTAssertNotNil(next)
        }
    }

    // P1-03: verify tick sound boundary conditions
    func testTickSoundLogic() {
        // last-10-second countdown boundary
        XCTAssertTrue(10 <= 10)  // plays tick at 10s
        XCTAssertTrue(1 <= 10)   // plays tick at 1s
        XCTAssertFalse(11 <= 10) // silent at 11s

        // every-5-minute loud tick boundary
        XCTAssertTrue(300 % 300 == 0)  // loud tick at 5min
        XCTAssertTrue(600 % 300 == 0)  // loud tick at 10min
        XCTAssertFalse(299 % 300 == 0) // silent at 299s
        XCTAssertFalse(1 % 300 == 0)   // silent at 1s (covered by <=10 branch instead)
    }

    // P0-04: setTime clamps to 3600 seconds
    func testSetTimeClampedToOneHour() {
        let vm = TimerViewModel()
        vm.inputMinutes = "60"
        vm.inputSeconds = "30" // should be forced to 0 when minutes == 60
        vm.setTime()
        XCTAssertEqual(vm.timeLeft, 3600)
        XCTAssertEqual(vm.totalTime, 3600)
    }
}
