import SwiftUI

/// Citymapper-style "Welcome to X" transition that covers the whole app
/// for ~1.6 s while the new country's dataset swaps underneath. Driven
/// by `AppState.countryTransition`; the overlay clears that field at
/// the end of the animation so the host view comes back automatically.
struct CountryTransitionOverlay: View {
    @Environment(AppState.self) private var appState
    @Environment(UserPreferences.self) private var preferences

    let country: Country

    @State private var phase: Phase = .enter
    @State private var hapticFired = false

    private var loc: Loc { preferences.loc }

    private enum Phase {
        case enter, visible, exit
    }

    // Approximate brand colours per country for the gradient backdrop.
    // Picked to match the flag while staying readable against white text.
    private var gradientColors: [Color] {
        switch country {
        case .spain:   [Color(red: 0.78, green: 0.10, blue: 0.18), Color(red: 0.98, green: 0.78, blue: 0.08)]
        case .france:  [Color(red: 0.00, green: 0.30, blue: 0.62), Color(red: 0.85, green: 0.15, blue: 0.20)]
        case .germany: [Color(red: 0.10, green: 0.10, blue: 0.10), Color(red: 0.99, green: 0.80, blue: 0.10)]
        case .italy:   [Color(red: 0.00, green: 0.55, blue: 0.30), Color(red: 0.85, green: 0.15, blue: 0.20)]
        case .uk:      [Color(red: 0.07, green: 0.15, blue: 0.45), Color(red: 0.78, green: 0.10, blue: 0.18)]
        case .usa:     [Color(red: 0.05, green: 0.14, blue: 0.42), Color(red: 0.78, green: 0.10, blue: 0.18)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                CountryFlagView(country: country, height: 110, cornerRadius: 14, withShadow: false)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .scaleEffect(phase == .enter ? 0.6 : 1.0)
                    .opacity(phase == .enter ? 0 : 1)

                VStack(spacing: 6) {
                    Text(loc.countryTransitionWelcome)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(country.displayName)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(modeDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 4)
                }
                .opacity(phase == .enter ? 0 : 1)
                .offset(y: phase == .enter ? 20 : 0)
            }
            .padding(.horizontal, 32)
        }
        .opacity(phase == .exit ? 0 : 1)
        .onAppear {
            // Spring-in, hold for ~1.1 s, fade out, then dismiss.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                phase = .visible
            }
            if !hapticFired {
                hapticFired = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    phase = .exit
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                if appState.countryTransition == country {
                    appState.countryTransition = nil
                }
            }
        }
    }

    private var modeDescription: String {
        if country.hasFuelData {
            return loc.countryTransitionFuelAndCharging
        }
        return loc.countryTransitionChargingOnly
    }
}
