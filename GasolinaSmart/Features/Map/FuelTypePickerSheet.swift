import SwiftUI

struct FuelTypePickerSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    private var loc: Loc { preferences.loc }

    private var supportedFuels: [FuelType] {
        preferences.selectedCountry.supportedFuelTypes
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(supportedFuels) { fuel in
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
            .navigationTitle(loc.fuel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc.close) { dismiss() }
                }
            }
        }
    }
}
