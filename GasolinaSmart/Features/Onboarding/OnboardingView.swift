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
            .animation(.easeInOut, value: currentPage)

            pageIndicator
                .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
    }

    private var welcomePage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "fuelpump.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Ahorra cada vez\nque repostas")
                    .font(Theme.Fonts.largeTitle)
                    .multilineTextAlignment(.center)

                Text("Encuentra la gasolinera más barata cerca de ti y decide cuándo repostar.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Empezar")
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var vehiclePage: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer().frame(height: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.tint)

                    Text("Configura tu vehículo")
                        .font(Theme.Fonts.title)

                    Text("Puedes añadir más vehículos en Ajustes.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Nombre")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                    TextField("Ej: Mi coche", text: $vehicleName)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Combustible")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .padding(.horizontal, Theme.Spacing.xl)

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(FuelType.allCases) { fuel in
                            Button {
                                selectedFuelType = fuel
                            } label: {
                                HStack {
                                    Image(systemName: fuel.icon)
                                        .frame(width: 24)
                                    Text(fuel.displayName)
                                        .font(Theme.Fonts.body)
                                    Spacer()
                                    if selectedFuelType == fuel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                                        .fill(selectedFuelType == fuel
                                              ? Color.accentColor.opacity(0.1)
                                              : Theme.Colors.secondaryBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                                        .stroke(selectedFuelType == fuel ? Color.accentColor : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                Spacer().frame(height: Theme.Spacing.md)

                Button {
                    let name = vehicleName.trimmingCharacters(in: .whitespaces)
                    let vehicle = Vehicle(
                        name: name.isEmpty ? "Mi coche" : name,
                        fuelType: selectedFuelType
                    )
                    preferences.vehicles = [vehicle]
                    preferences.selectedVehicleId = vehicle.id
                    withAnimation { currentPage = 2 }
                } label: {
                    Text("Continuar")
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var locationPage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.tint)

                Text("Tu ubicación")
                    .font(Theme.Fonts.title)

                Text("Necesitamos tu ubicación para encontrar gasolineras cerca de ti. No compartimos tu posición con nadie.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    locationManager.requestPermission()
                } label: {
                    Text("Permitir ubicación")
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    completeOnboarding()
                } label: {
                    Text("Ahora no")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways || status == .denied {
                completeOnboarding()
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Theme.Colors.tertiaryLabel)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }
}
