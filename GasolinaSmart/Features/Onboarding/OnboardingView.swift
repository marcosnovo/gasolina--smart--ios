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
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Ahorra cada vez\nque repostas")
                .font(.largeTitle.weight(.bold))
                .lineSpacing(4)
                .padding(.bottom, 16)

            Text("Encuentra la gasolinera más barata cerca de ti y decide cuándo repostar.")
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))

            Spacer()
            Spacer()

            OnboardingButton(title: "Empezar") {
                withAnimation { currentPage = 1 }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Vehicle Setup

    private var vehiclePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 48)

                Text("Tu vehículo")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 4)

                Text("Puedes añadir más en Ajustes.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.bottom, 28)

                Text("Nombre")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .padding(.bottom, 4)

                TextField("Ej: Mi coche", text: $vehicleName)
                    .font(.body)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .padding(.bottom, 24)

                Text("Combustible")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(FuelType.allCases) { fuel in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFuelType = fuel
                            }
                        } label: {
                            HStack {
                                Text(fuel.displayName)
                                    .font(.body)
                                Spacer()
                                if selectedFuelType == fuel {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 32)

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
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Location

    private var locationPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Tu ubicación")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 16)

            Text("Necesitamos tu ubicación para encontrar gasolineras cerca de ti.\n\nNo compartimos tu posición con nadie.")
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))
                .lineSpacing(4)

            Spacer()
            Spacer()

            VStack(spacing: 8) {
                OnboardingButton(title: "Permitir ubicación") {
                    locationManager.requestPermission()
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text("Ahora no")
                        .font(.subheadline)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(.horizontal, 24)
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
                    .fill(index == currentPage ? Color(.label) : Color(.tertiaryLabel).opacity(0.3))
                    .frame(width: index == currentPage ? 16 : 6, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    private func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }
}

private struct OnboardingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.Colors.accent)
    }
}
