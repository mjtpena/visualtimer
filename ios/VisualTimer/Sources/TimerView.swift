import SwiftUI

struct TimerView: View {
    @StateObject private var vm = TimerViewModel()

    private var bgColor: Color {
        vm.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : .white
    }

    private var fgColor: Color {
        vm.isDarkMode ? .white : .black
    }

    private var accentColor: Color {
        vm.isDarkMode ? Color(red: 0.3, green: 0.65, blue: 1.0) : .black
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top buttons
                HStack(spacing: 4) {
                    Spacer()
                    toolbarButton(icon: "arrow.up.left.and.arrow.down.right") {
                        vm.toggleClockSize()
                    }
                    toolbarButton(icon: "arrow.left.arrow.right") {
                        vm.toggleFlip()
                    }
                    toolbarButton(icon: vm.audioManager.isSoundOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                        vm.audioManager.toggleSound()
                    }
                    toolbarButton(icon: vm.isDarkMode ? "sun.max.fill" : "moon.fill") {
                        vm.toggleDarkMode()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // Clock face
                ClockFaceView(
                    timeLeft: vm.timeLeft,
                    clockSize: vm.clockDimension,
                    timerRadius: vm.timerRadius,
                    borderWidth: vm.borderWidth,
                    isDarkMode: vm.isDarkMode,
                    isFlipped: vm.isFlipped
                )

                // Digital time display
                Text(vm.formattedTime())
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(fgColor)
                    .padding(.top, 20)

                // Controls
                HStack(spacing: 10) {
                    if vm.showInput {
                        inputControls
                    } else {
                        playbackControls
                    }
                }
                .padding(.top, 20)

                Spacer()
            }
        }
        .onAppear {
            vm.audioManager.loadSounds()
        }
    }

    // MARK: - Input Controls

    private var inputControls: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Minutes", text: $vm.inputMinutes)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(fgColor)
                    .padding(.bottom, 5)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(vm.inputMinutes.isEmpty ? (vm.isDarkMode ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)) : accentColor),
                        alignment: .bottom
                    )
                    .frame(width: 150)
                    .onChange(of: vm.inputMinutes) { _, newValue in
                        vm.handleInputChange(newValue, isMinutes: true)
                    }

                TextField("Seconds", text: $vm.inputSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(fgColor)
                    .padding(.bottom, 5)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(vm.inputSeconds.isEmpty ? (vm.isDarkMode ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)) : accentColor),
                        alignment: .bottom
                    )
                    .frame(width: 150)
                    .onChange(of: vm.inputSeconds) { _, newValue in
                        vm.handleInputChange(newValue, isMinutes: false)
                    }

                Text("Enter time (max 60 minutes)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Button(action: vm.setTime) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 12) {
            controlButton(icon: vm.isRunning ? "pause.fill" : "play.fill") {
                vm.startStop()
            }
            controlButton(icon: "stop.circle.fill") {
                vm.reset()
            }
        }
    }

    // MARK: - Button Helpers

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .padding(10)
                .background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .cornerRadius(8)
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(accentColor)
                .padding(10)
                .background(vm.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .cornerRadius(8)
        }
    }
}

#Preview {
    TimerView()
}
