import SwiftUI

struct PropertyChoiceMenu: View {
    let row: PropertyRow
    let options: [PropertyOption]
    let onSelect: (String) -> Void

    var body: some View {
        Menu(row.display) {
            ForEach(options) { option in
                Button {
                    onSelect(option.valueJson)
                } label: {
                    Label(option.label, systemImage: option.valueJson == row.valueJson ? "checkmark" : "circle")
                }
            }
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(row.label)
        .accessibilityValue(row.display)
    }
}
