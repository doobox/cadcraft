import SwiftUI

struct ToolSectionView: View {
    let section: ToolSection
    let action: (ToolDefinition) -> Void

    @State private var isExpanded = true
    private let secondaryColumns = [GridItem(.adaptive(minimum: 25, maximum: 25), spacing: 3)]

    var body: some View {
        DisclosureGroup(section.title, isExpanded: $isExpanded) {
            if !section.featuredTools.isEmpty {
                HStack(spacing: 8) {
                    ForEach(section.featuredTools) { tool in
                        ToolButton(tool: tool, buttonSize: 40, iconSize: 34, action: action)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LazyVGrid(columns: secondaryColumns, alignment: .leading, spacing: 3) {
                ForEach(section.tools) { tool in
                    ToolButton(tool: tool, buttonSize: 25, iconSize: 20, action: action)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, section.featuredTools.isEmpty ? 0 : 2)
        }
    }
}
