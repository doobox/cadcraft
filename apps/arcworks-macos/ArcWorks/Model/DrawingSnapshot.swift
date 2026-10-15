import Foundation

struct DrawingSnapshot: Codable, Sendable {
    let title: String
    let path: String?
    let dirty: Bool
    let undoLabel: String?
    let redoLabel: String?
    let clipboardSerial: UInt64?
    let prompt: String
    let history: [String]
    let entityCount: Int
    let selectionCount: Int
    let canWindowSelect: Bool
    let bounds: [Float]
    let view: DrawingViewState
    let strokes: [StrokePrimitive]
    let triangles: [TrianglePrimitive]
    let grips: [GripPrimitive]
    let drafting: DraftingState
    let layouts: [String]
    let currentLayout: String
    let annotationScales: [String]
    let currentAnnotationScale: String
    let layers: [LayerSummary]
    let linetypes: [String]
    let linetypeLibrary: [String]
    let layerStates: [String]
    let hasActiveViewport: Bool
    let selectionTypes: [SelectionType]
    let propertyGroups: [PropertyGroup]

    static let empty = DrawingSnapshot(
        title: "ArcWorks",
        path: nil,
        dirty: false,
        undoLabel: nil,
        redoLabel: nil,
        clipboardSerial: nil,
        prompt: "Command:",
        history: [],
        entityCount: 0,
        selectionCount: 0,
        canWindowSelect: true,
        bounds: [-10, -10, 10, 10],
        view: DrawingViewState(center: WorldPoint(x: 6, y: 4.5), height: 10),
        strokes: [],
        triangles: [],
        grips: [],
        drafting: .default,
        layouts: [],
        currentLayout: "Model",
        annotationScales: ["1:1"],
        currentAnnotationScale: "1:1",
        layers: [],
        linetypes: [],
        linetypeLibrary: [],
        layerStates: [],
        hasActiveViewport: false,
        selectionTypes: [],
        propertyGroups: []
    )
}

