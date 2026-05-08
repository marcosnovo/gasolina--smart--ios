import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @State private var currentPage = 0
    @State private var vehicleName = ""
    @State private var selectedFuelType: FuelType = .gasolina95

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                vehiclePage.tag(1)
                locationPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            pageIndicator
                .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(Color.accentColor.opacity(0.06))
                        .frame(width: 170, height: 170)
                    Image(systemName: "fuelpump.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5))
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Ahorra cada vez\nque repostas")
                        .font(Theme.Fonts.largeTitle)
                        .multilineTextAlignment(.center)

                    Text("Encuentra la gasolinera más barata\ncerca de ti y decide cuándo repostar.")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            Spacer()
            Spacer()

            OnboardingButton(title: "Empezar") {
                withAnimation { currentPage = 1 }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Vehicle Setup

    private var vehiclePage: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer().frame(height: Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 90, height: 90)
                        Image(systemName: "car.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tint)
                    }

                    Text("Configura tu vehículo")
                        .font(Theme.Fonts.title)

                    Text("Puedes añadir más vehículos en Ajustes.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOMBRE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .tracking(0.5)
                    TextField("Ej: Mi coche", text: $vehicleName)
                        .font(Theme.Fonts.body)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                VStack(alignment: .leading, spacing: 6) {
                    Text("COMBUSTIBLE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .tracking(0.5)
                        .padding(.horizontal, Theme.Spacing.xl)

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(FuelType.allCases) { fuel in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFuelType = fuel
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: fuel.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(selectedFuelType == fuel ? Color.accentColor : .secondary)
                                        .frame(width: 24)
                                    Text(fuel.displayName)
                                        .font(Theme.Fonts.body)
                                        .foregroundStyle(Theme.Colors.label)
                                    Spacer()
                                    if selectedFuelType == fuel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .fill(selectedFuelType == fuel
                                              ? Color.accentColor.opacity(0.08)
                                              : Theme.Colors.secondaryBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .stroke(selectedFuelType == fuel ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                Spacer().frame(height: Theme.Spacing.sm)

                OnboardingButton(title: "Continuar") {
                    let name = vehicleName.trimmingCharacters(in: .whitespaces)
                    let vehicle = Vehicle(
                        name: name.isEmpty ? "Mi coche" : name,
                        fuelType: selectedFuelType
                    )
                    preferences.vehicles = [vehicle]
                    preferences.selectedVehicleId = vehicle.id
                    withAnimation { currentPage = 2 }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Location

    private var locationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(Color.blue.opacity(0.06))
                        .frame(width: 170, height: 170)
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Tu ubicación")
                        .font(Theme.Fonts.title)

                    Text("Necesitamos tu ubicación para encontrar\ngasolineras cerca de ti.\nNo compartimos tu posición con nadie.")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            Spacer()
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                OnboardingButton(title: "Permitir ubicación") {
                    locationManager.requestPermission()
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text("Ahora no")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.tertiaryLabel)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways || status == .denied {
                completeOnboarding()
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.accentColor : Theme.Colors.tertiaryLabel.opacity(0.4))
                    .frame(width: index == currentPage ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    private func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding Button

private struct OnboardingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Colors.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
