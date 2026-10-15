import SwiftUI

struct DrawingScaleMenu: View {
    let document: DrawingDocument

    var body: some View {
        Menu {
            ForEach(document.snapshot.annotationScales, id: \.self) { scale in
                Button {
                    document.setAnnotationScale(scale)
                } label: {
                    if scale == document.snapshot.currentAnnotationScale {
                        Label(scale, systemImage: "checkmark")
                    } else {
                        Text(scale)
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(document.snapshot.currentAnnotationScale)
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Annotation Scale")
    }
}
