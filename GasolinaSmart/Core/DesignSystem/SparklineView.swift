import SwiftUI

struct SparklineView: View {
    let values: [Double]
    var color: Color = Theme.Colors.accent
    var height: CGFloat = 48

    var body: some View {
        if values.count >= 2 {
            GeometryReader { geo in
                let minVal = values.min()!
                let maxVal = values.max()!
                let range = maxVal - minVal
                let w = geo.size.width
                let h = geo.size.height
                let step = w / CGFloat(values.count - 1)

                ZStack(alignment: .topLeading) {
                    lineFill(step: step, h: h, w: w, minVal: minVal, range: range)
                    linePath(step: step, h: h, minVal: minVal, range: range)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    endDot(step: step, h: h, minVal: minVal, range: range)
                }
            }
            .frame(height: height)
        }
    }

    private func yPosition(_ value: Double, h: CGFloat, minVal: Double, range: Double) -> CGFloat {
        let padding: CGFloat = 4
        let usable = h - padding * 2
        guard range > 0 else { return h / 2 }
        return padding + usable * (1 - CGFloat((value - minVal) / range))
    }

    private func linePath(step: CGFloat, h: CGFloat, minVal: Double, range: Double) -> Path {
        Path { path in
            for (i, value) in values.enumerated() {
                let x = step * CGFloat(i)
                let y = yPosition(value, h: h, minVal: minVal, range: range)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func lineFill(step: CGFloat, h: CGFloat, w: CGFloat, minVal: Double, range: Double) -> some View {
        Path { path in
            for (i, value) in values.enumerated() {
                let x = step * CGFloat(i)
                let y = yPosition(value, h: h, minVal: minVal, range: range)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.addLine(to: CGPoint(x: step * CGFloat(values.count - 1), y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [color.opacity(0.25), color.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func endDot(step: CGFloat, h: CGFloat, minVal: Double, range: Double) -> some View {
        let lastValue = values.last!
        let x = step * CGFloat(values.count - 1)
        let y = yPosition(lastValue, h: h, minVal: minVal, range: range)
        return Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .position(x: x, y: y)
    }
}
