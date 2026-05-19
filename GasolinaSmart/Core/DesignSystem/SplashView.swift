import SwiftUI

/// Cold-launch splash: a full-screen green field with a pulsing radar
/// in the centre, then an "iris open" wipe that grows from the radar
/// outwards to reveal the map underneath.
///
/// Mounted by ContentView once per process lifetime. The view drives
/// its own animation and fires `onComplete` when the iris has fully
/// uncovered the content beneath.
struct SplashView: View {
    var onComplete: () -> Void

    @State private var phase: Phase = .enter
    @State private var holeRadius: CGFloat = 0
    @State private var pulseTrigger = 0
    @State private var coreScale: CGFloat = 0.7

    private enum Phase {
        case enter      // pin scaling up from 0.7 to 1.0
        case pulsing    // three concentric pulses radiating outward
        case opening    // iris wipe — the green is being eaten from the centre
        case done       // host can stop rendering this view
    }

    var body: some View {
        GeometryReader { geo in
            let maxRadius = hypot(geo.size.width, geo.size.height) // covers any aspect

            ZStack {
                // 1) The green field with a circular hole growing from the
                //    centre. `eoFill` paints "rectangle minus circle" so
                //    the underlying view (the map) leaks through.
                SpotlightShape(holeRadius: holeRadius)
                    .fill(Theme.Colors.accent, style: FillStyle(eoFill: true))
                    .ignoresSafeArea()

                // 2) The radar — three pulse rings + a centre dot.
                RadarPulse(trigger: pulseTrigger)
                    .scaleEffect(coreScale)
                    .opacity(phase == .opening || phase == .done ? 0 : 1)
                    .animation(.easeInOut(duration: 0.35), value: phase)
            }
            .onAppear {
                runAnimation(maxRadius: maxRadius)
            }
        }
    }

    private func runAnimation(maxRadius: CGFloat) {
        // Pin springs up.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            coreScale = 1.0
        }
        // Three pulses, ~0.45 s apart, then start the iris open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)  { pulseTrigger += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { pulseTrigger += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) { pulseTrigger += 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            phase = .opening
            withAnimation(.easeIn(duration: 0.65)) {
                holeRadius = maxRadius * 1.15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            phase = .done
            onComplete()
        }
    }
}

// MARK: - Spotlight Shape (rectangle minus growing centre circle)

private struct SpotlightShape: Shape {
    var holeRadius: CGFloat

    var animatableData: CGFloat {
        get { holeRadius }
        set { holeRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(0, holeRadius)
        path.addEllipse(in: CGRect(
            x: centre.x - r,
            y: centre.y - r,
            width: r * 2,
            height: r * 2
        ))
        return path
    }
}

// MARK: - Radar pulse (three rings + centre)

private struct RadarPulse: View {
    /// Increment to fire another pulse. Each ring listens to a specific
    /// `trigger` value so the three rings stagger naturally.
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                PulseRing(targetTrigger: i + 1, currentTrigger: trigger)
            }

            // Centre marker — white circle with a green dot, evoking the
            // "cheapest pin" the user is about to see on the map.
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 28, height: 28)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 220, height: 220)
    }
}

private struct PulseRing: View {
    let targetTrigger: Int
    let currentTrigger: Int

    @State private var scale: CGFloat = 0.25
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.75), lineWidth: 2.5)
            .frame(width: 220, height: 220)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: currentTrigger) { _, newValue in
                guard newValue == targetTrigger else { return }
                scale = 0.25
                opacity = 0.6
                withAnimation(.easeOut(duration: 1.4)) {
                    scale = 1.4
                    opacity = 0
                }
            }
    }
}
