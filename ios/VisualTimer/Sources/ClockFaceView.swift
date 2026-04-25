import SwiftUI

struct ClockFaceView: View {
    let timeLeft: Int
    let totalTime: Int      // P1-02: dynamic scale instead of hardcoded 3600
    let clockSize: CGFloat
    let timerRadius: CGFloat
    let borderWidth: CGFloat
    let isDarkMode: Bool
    let isFlipped: Bool

    private var center: CGPoint {
        CGPoint(x: clockSize / 2, y: clockSize / 2)
    }

    private var strokeColor: Color {
        isDarkMode ? .white : .black
    }

    private var fillColor: Color {
        isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : .white
    }

    private var arcColor: Color {
        isDarkMode ? Color(red: 0.3, green: 0.65, blue: 1.0) : .red
    }

    var body: some View {
        Canvas { context, size in
            let cx = clockSize / 2
            let cy = clockSize / 2
            let center = CGPoint(x: cx, y: cy)
            let arcRadius = timerRadius - borderWidth / 2

            // Outer circle
            let outerCircle = Path(ellipseIn: CGRect(
                x: cx - timerRadius, y: cy - timerRadius,
                width: timerRadius * 2, height: timerRadius * 2
            ))
            context.fill(outerCircle, with: .color(fillColor))
            context.stroke(outerCircle, with: .color(strokeColor), lineWidth: borderWidth)

            // P1-02 + P0-02: arc using totalTime scale; full-circle fix when fraction ≥ 0.9999
            if timeLeft > 0 && totalTime > 0 {
                let fraction = Double(timeLeft) / Double(totalTime)
                if fraction >= 0.9999 {
                    // P0-02: draw a complete ellipse to avoid degenerate arc (start == end)
                    let fullArc = Path(ellipseIn: CGRect(
                        x: cx - arcRadius, y: cy - arcRadius,
                        width: arcRadius * 2, height: arcRadius * 2
                    ))
                    context.fill(fullArc, with: .color(arcColor))
                } else {
                    let startAngle = Angle.degrees(-90)
                    let endAngle = Angle.degrees(fraction * 360.0 - 90)
                    var arcPath = Path()
                    arcPath.move(to: center)
                    arcPath.addArc(center: center, radius: arcRadius,
                                  startAngle: startAngle, endAngle: endAngle,
                                  clockwise: true)
                    arcPath.closeSubpath()
                    context.fill(arcPath, with: .color(arcColor))
                }
            }

            // Minute marks
            for i in 0..<60 {
                let angle = Double(i) * 6.0 - 90.0
                let rad = angle * .pi / 180.0
                let isMajor = i % 5 == 0
                let length: CGFloat = isMajor ? 15 : 7
                let innerR = arcRadius - length
                let outerR = arcRadius

                let x1 = cx + innerR * cos(rad)
                let y1 = cy + innerR * sin(rad)
                let x2 = cx + outerR * cos(rad)
                let y2 = cy + outerR * sin(rad)

                var mark = Path()
                mark.move(to: CGPoint(x: x1, y: y1))
                mark.addLine(to: CGPoint(x: x2, y: y2))
                context.stroke(mark, with: .color(strokeColor),
                              lineWidth: isMajor ? 2 : 1)
            }

            // Hour numbers (0, 5, 10, ... 55)
            for i in 0..<12 {
                let angle = Double(i) * 30.0
                let rad = angle * .pi / 180.0
                let numberRadius = timerRadius - 40
                let nx = cx + numberRadius * sin(rad)
                let ny = cy - numberRadius * cos(rad)

                let text = Text(i == 0 ? "60" : "\(i * 5)")
                    .font(.system(size: clockSize / 15))
                    .foregroundColor(strokeColor)

                let resolvedText = context.resolve(text)
                context.draw(resolvedText, at: CGPoint(x: isFlipped ? clockSize - nx : nx, y: ny), anchor: .center)
            }

            // P1-02: clock hand uses totalTime scale
            if timeLeft > 0 && totalTime > 0 {
                let fraction = Double(timeLeft) / Double(totalTime)
                let handAngle = fraction * 360.0 - 90.0
                let handRad = handAngle * .pi / 180.0
                let handLength = timerRadius - 40
                let hx = cx + handLength * cos(handRad)
                let hy = cy + handLength * sin(handRad)

                var hand = Path()
                hand.move(to: center)
                hand.addLine(to: CGPoint(x: hx, y: hy))
                context.stroke(hand, with: .color(strokeColor), lineWidth: 6)
            }

            // Center donut
            let outerDot = Path(ellipseIn: CGRect(x: cx - 20, y: cy - 20, width: 40, height: 40))
            context.fill(outerDot, with: .color(strokeColor))

            let innerDot = Path(ellipseIn: CGRect(x: cx - 15, y: cy - 15, width: 30, height: 30))
            context.fill(innerDot, with: .color(fillColor))
        }
        .frame(width: clockSize, height: clockSize)
        .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
        .accessibilityHidden(true) // P2-01: decorative canvas, VoiceOver reads the digital text
    }
}
