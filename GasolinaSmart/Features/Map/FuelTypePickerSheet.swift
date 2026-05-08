import SwiftUI

struct FuelTypePickerSheet: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(FuelType.allCases) { fuel in
                    Button {
                        preferences.selectedFuelType = fuel
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: fuel.icon)
                                .frame(width: 24)
                                .foregroundStyle(.tint)
                            Text(fuel.displayName)
                                .foregroundStyle(Theme.Colors.label)
                            Spacer()
                            if preferences.selectedFuelType == fuel {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Combustible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
