import SwiftUI

/// Vector flag illustrations per country. Apple's flag emoji renders
/// inconsistently across sizes and OS versions and doesn't sit well
/// inside the rest of the design system. These hand-built SwiftUI
/// compositions look like premium stickers at any size, scale
/// crisply, and match the country picker's brand-card aesthetic.
///
/// All flags use a 3:2 aspect ratio for visual consistency, with a
/// subtle border + shadow so they read as physical objects rather
/// than flat colour blocks.
struct CountryFlagView: View {
    let country: Country
    var height: CGFloat = 36
    var cornerRadius: CGFloat = 6
    var withShadow: Bool = true

    private var width: CGFloat { height * 1.5 }

    var body: some View {
        flag
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
            )
            .shadow(
                color: withShadow ? Color.black.opacity(0.18) : .clear,
                radius: withShadow ? 3 : 0,
                y: withShadow ? 1.5 : 0
            )
    }

    @ViewBuilder
    private var flag: some View {
        switch country {
        case .spain:   SpainFlag()
        case .france:  FranceFlag()
        case .germany: GermanyFlag()
        case .italy:   ItalyFlag()
        case .uk:      UKFlag()
        case .usa:     USAFlag()
        }
    }
}

// MARK: - Spain (red / yellow-2x / red — official 1:2:1 ratio)

private struct SpainFlag: View {
    private let red = Color(red: 0.78, green: 0.10, blue: 0.18)
    private let yellow = Color(red: 0.98, green: 0.78, blue: 0.08)

    var body: some View {
        // Explicit proportions via GeometryReader — using `frame(maxHeight: .infinity)`
        // + layoutPriority squashed the red bands to zero at small sizes.
        GeometryReader { geo in
            let h = geo.size.height
            VStack(spacing: 0) {
                red.frame(height: h * 0.25)
                yellow.frame(height: h * 0.50)
                red.frame(height: h * 0.25)
            }
        }
    }
}

// MARK: - France (blue | white | red)

private struct FranceFlag: View {
    private let blue = Color(red: 0.00, green: 0.32, blue: 0.65)
    private let red = Color(red: 0.93, green: 0.16, blue: 0.22)

    var body: some View {
        HStack(spacing: 0) {
            blue
            Color.white
            red
        }
    }
}

// MARK: - Italy (green | white | red)

private struct ItalyFlag: View {
    private let green = Color(red: 0.00, green: 0.55, blue: 0.30)
    private let red = Color(red: 0.81, green: 0.13, blue: 0.20)

    var body: some View {
        HStack(spacing: 0) {
            green
            Color.white
            red
        }
    }
}

// MARK: - Germany (black / red / gold)

private struct GermanyFlag: View {
    private let red = Color(red: 0.86, green: 0.12, blue: 0.12)
    private let gold = Color(red: 0.99, green: 0.80, blue: 0.10)

    var body: some View {
        VStack(spacing: 0) {
            Color.black
            red
            gold
        }
    }
}

// MARK: - UK (simplified Union Jack)

private struct UKFlag: View {
    private let navy = Color(red: 0.04, green: 0.13, blue: 0.40)
    private let red = Color(red: 0.81, green: 0.09, blue: 0.18)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                navy

                // White diagonals (St Andrew's + St Patrick's superimposed).
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.move(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: h))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: h * 0.30, lineCap: .butt))

                // Red diagonals (slightly thinner, on top of the white).
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.move(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: h))
                }
                .stroke(red, style: StrokeStyle(lineWidth: h * 0.12, lineCap: .butt))

                // White cross (St George's background).
                Rectangle().fill(Color.white).frame(width: w, height: h * 0.36)
                Rectangle().fill(Color.white).frame(width: h * 0.36, height: h)

                // Red cross on top.
                Rectangle().fill(red).frame(width: w, height: h * 0.18)
                Rectangle().fill(red).frame(width: h * 0.18, height: h)
            }
            .clipped()
        }
    }
}

// MARK: - USA (13 stripes + canton with star grid)

private struct USAFlag: View {
    private let red = Color(red: 0.70, green: 0.10, blue: 0.20)
    private let navy = Color(red: 0.05, green: 0.16, blue: 0.42)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stripeHeight = h / 13
            let cantonW = w * 0.40
            let cantonH = stripeHeight * 7

            ZStack(alignment: .topLeading) {
                // 13 alternating stripes (red on odd, white on even).
                VStack(spacing: 0) {
                    ForEach(0..<13, id: \.self) { i in
                        (i.isMultiple(of: 2) ? red : Color.white)
                            .frame(height: stripeHeight)
                    }
                }

                // Canton.
                navy.frame(width: cantonW, height: cantonH)

                // Star grid — simplified to a 5×4 pattern of small dots so
                // the symbol reads as "USA" at small sizes without trying
                // to render 50 actual stars (illegible below ~80pt).
                let rows = 5
                let cols = 4
                let starSize = min(cantonW, cantonH) * 0.10
                let hPad = (cantonW - CGFloat(cols) * starSize) / CGFloat(cols + 1)
                let vPad = (cantonH - CGFloat(rows) * starSize) / CGFloat(rows + 1)

                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        Circle()
                            .fill(Color.white)
                            .frame(width: starSize, height: starSize)
                            .offset(
                                x: hPad + CGFloat(c) * (starSize + hPad),
                                y: vPad + CGFloat(r) * (starSize + vPad)
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(Country.allCases) { country in
            HStack(spacing: 16) {
                CountryFlagView(country: country, height: 36)
                CountryFlagView(country: country, height: 60)
                CountryFlagView(country: country, height: 96)
                Text(country.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
        }
    }
    .padding()
}
