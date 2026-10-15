import SwiftUI

struct DraftingStatusControls: View {
    let state: DraftingState
    let onToggle: (DraftingSetting) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(DraftingSetting.allCases) { setting in
                let isEnabled = setting.isEnabled(in: state)
                Button {
                    onToggle(setting)
                } label: {
                    Label {
                        Text(setting.accessibilityLabel)
                    } icon: {
                        ArcWorksIconView(
                            setting.icon,
                            monochrome: isEnabled ? .white : Color(nsColor: .secondaryLabelColor)
                        )
                        .frame(width: 15, height: 15)
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: WorkspaceMetrics.statusButtonSize, height: WorkspaceMetrics.statusButtonSize)
                .background(isEnabled ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 3))
                .accessibilityValue(isEnabled ? "On" : "Off")
                .help("Toggle \(setting.accessibilityLabel) (\(setting.shortcutLabel))")
            }
        }
    }
}
