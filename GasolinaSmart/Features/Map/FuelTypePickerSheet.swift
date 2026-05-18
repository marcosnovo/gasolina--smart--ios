import SwiftUI

struct FuelTypePickerSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    private var loc: Loc { preferences.loc }

    private var vehicleFuels: [FuelType] {
        preferences.vehicleSupportedFuels
    }

    private var otherFuels: [FuelType] {
        preferences.selectedCountry.supportedFuelTypes.filter { !vehicleFuels.contains($0) }
    }

    private var isDualFuelVehicle: Bool {
        vehicleFuels.count > 1
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vehicleFuels) { fuel in
                        fuelRow(fuel)
                    }
                } header: {
                    if isDualFuelVehicle {
                        Text(loc.fuelPickerVehicleSection)
                    }
                } footer: {
                    if isDualFuelVehicle {
                        Text(loc.fuelPickerDualFuelHint)
                    }
                }

                if !otherFuels.isEmpty {
                    Section {
                        ForEach(otherFuels) { fuel in
                            fuelRow(fuel)
                        }
                    } header: {
                        Text(loc.fuelPickerOtherSection)
                    }
                }
            }
            .navigationTitle(loc.fuel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }

    private func fuelRow(_ fuel: FuelType) -> some View {
        Button {
            preferences.selectedFuelType = fuel
            dismiss()
        } label: {
            HStack {
                Image(systemName: fuel.icon)
                    .frame(width: 24)
                    .foregroundStyle(.blue)
                Text(fuel.displayName(for: preferences.selectedCountry))
                Spacer()
                if preferences.selectedFuelType == fuel {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
