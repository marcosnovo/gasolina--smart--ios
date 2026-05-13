import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(LocationManager.self) private var locationManager
    @State private var currentPage = 0
    @State private var vehicleName = ""
    @State private var selectedFuelType: FuelType = .gasolina95
    @State private var selectedCountry: Country = .spain

    private var loc: Loc { preferences.loc }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                countryPage.tag(1)
                vehiclePage.tag(2)
                locationPage.tag(3)
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

            Text(loc.onboardingTitle)
                .font(.largeTitle.weight(.bold))
                .lineSpacing(4)
                .padding(.bottom, 16)

            Text(loc.onboardingSubtitle)
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))

            Spacer()
            Spacer()

            OnboardingButton(title: loc.onboardingStart) {
                withAnimation { currentPage = 1 }
            }
            .onAppear {
                if let location = locationManager.location,
                   let detected = Country.detect(from: location.coordinate) {
                    selectedCountry = detected
                    selectedFuelType = detected.defaultFuel
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Country Selection

    private var countryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 48)

                Text(loc.onboardingCountryTitle)
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 4)

                Text(loc.onboardingCountrySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.bottom, 28)

                VStack(spacing: 0) {
                    ForEach(Country.allCases) { country in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCountry = country
                                selectedFuelType = country.defaultFuel
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag)
                                    .font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(country.displayName)
                                        .font(.body)
                                    Text(loc.freshnessText(country.dataFreshness))
                                        .font(.caption)
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                Spacer()
                                if selectedCountry == country {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 32)

                OnboardingButton(title: loc.onboardingContinue) {
                    withAnimation { currentPage = 2 }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Vehicle Setup

    private var vehiclePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 48)

                Text(loc.onboardingVehicleTitle)
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 4)

                Text(loc.onboardingVehicleHint)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.bottom, 28)

                Text(loc.name)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .padding(.bottom, 4)

                TextField(loc.namePlaceholder, text: $vehicleName)
                    .font(.body)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .padding(.bottom, 24)

                Text(loc.fuel)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .textCase(.uppercase)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(selectedCountry.supportedFuelTypes) { fuel in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFuelType = fuel
                            }
                        } label: {
                            HStack {
                                Text(fuel.displayName(for: selectedCountry))
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

                OnboardingButton(title: loc.onboardingContinue) {
                    let name = vehicleName.trimmingCharacters(in: .whitespaces)
                    let vehicle = Vehicle(
                        name: name.isEmpty ? loc.onboardingDefaultVehicle : name,
                        fuelType: selectedFuelType
                    )
                    preferences.vehicles = [vehicle]
                    preferences.selectedVehicleId = vehicle.id
                    preferences.selectedCountry = selectedCountry
                    withAnimation { currentPage = 3 }
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

            Text(loc.onboardingLocationTitle)
                .font(.title2.weight(.semibold))
                .padding(.bottom, 16)

            Text(loc.onboardingLocationBody)
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))
                .lineSpacing(4)

            Spacer()
            Spacer()

            VStack(spacing: 8) {
                OnboardingButton(title: loc.onboardingAllowLocation) {
                    locationManager.requestPermission()
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text(loc.onboardingNotNow)
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
            ForEach(0..<4, id: \.self) { index in
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
