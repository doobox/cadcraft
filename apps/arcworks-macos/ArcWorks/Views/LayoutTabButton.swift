import SwiftUI

struct LayoutTabButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(name, action: action)
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: WorkspaceMetrics.statusBarHeight)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            .overlay(alignment: .top) {
                if isSelected {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
