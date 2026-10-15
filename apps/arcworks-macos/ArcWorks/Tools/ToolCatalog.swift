import Foundation

enum ToolCatalog {
    static let sections = [
        ToolSection(
            title: "Draw",
            featuredTools: [
                ToolDefinition(command: "line", label: "Line", icon: .line),
                ToolDefinition(command: "pline", label: "Polyline", icon: .polyline),
                ToolDefinition(command: "circle", label: "Circle", icon: .circle),
                ToolDefinition(command: "rectang", label: "Rectangle", icon: .rectangle)
            ],
            tools: [
                ToolDefinition(command: "arc", label: "Arc", icon: .arc),
                ToolDefinition(command: "spline", label: "Spline", icon: .spline),
                ToolDefinition(command: "xline", label: "Construction Line", icon: .constructionLine),
                ToolDefinition(command: "ray", label: "Ray", icon: .ray),
                ToolDefinition(command: "ellipse", label: "Ellipse", icon: .ellipse),
                ToolDefinition(command: "polygon", label: "Polygon", icon: .polygon),
                ToolDefinition(command: "point", label: "Point", icon: .point),
                ToolDefinition(command: "donut", label: "Donut", icon: .donut),
                ToolDefinition(command: "revcloud", label: "Revision Cloud", icon: .revisionCloud),
                ToolDefinition(command: "region", label: "Region", icon: .region),
                ToolDefinition(command: "wipeout", label: "Wipeout", icon: .wipeout)
            ]
        ),
        ToolSection(
            title: "Hatch",
            featuredTools: [
                ToolDefinition(command: "hatch", label: "Hatch", icon: .hatch),
                ToolDefinition(command: "gradient", label: "Gradient", icon: .gradient),
                ToolDefinition(command: "boundary", label: "Boundary", icon: .boundary)
            ],
            tools: []
        ),
        ToolSection(
            title: "Block",
            featuredTools: [
                ToolDefinition(command: "block", label: "Create Block", icon: .block),
                ToolDefinition(command: "insert", label: "Insert Block", icon: .insert),
                ToolDefinition(command: "bedit", label: "Block Editor", icon: .blockEdit),
                ToolDefinition(command: "attdef", label: "Define Attributes", icon: .attribute)
            ],
            tools: []
        ),
        ToolSection(
            title: "Modify",
            featuredTools: [
                ToolDefinition(command: "move", label: "Move", icon: .move)
            ],
            tools: [
                ToolDefinition(command: "copy", label: "Copy", icon: .copy),
                ToolDefinition(command: "rotate", label: "Rotate", icon: .rotate),
                ToolDefinition(command: "trim", label: "Trim", icon: .trim),
                ToolDefinition(command: "fillet", label: "Fillet", icon: .fillet),
                ToolDefinition(command: "arrayrect", label: "Rectangular Array", icon: .arrayRectangular),
                ToolDefinition(command: "mirror", label: "Mirror", icon: .mirror),
                ToolDefinition(command: "scale", label: "Scale", icon: .scale),
                ToolDefinition(command: "extend", label: "Extend", icon: .extend),
                ToolDefinition(command: "offset", label: "Offset", icon: .offset),
                ToolDefinition(command: "arraypolar", label: "Polar Array", icon: .arrayPolar),
                ToolDefinition(command: "stretch", label: "Stretch", icon: .stretch),
                ToolDefinition(command: "chamfer", label: "Chamfer", icon: .chamfer),
                ToolDefinition(command: "explode", label: "Explode", icon: .explode),
                ToolDefinition(command: "break", label: "Break", icon: .breakLine),
                ToolDefinition(command: "join", label: "Join", icon: .join),
                ToolDefinition(command: "erase", label: "Erase", icon: .erase),
                ToolDefinition(command: "lengthen", label: "Lengthen", icon: .lengthen),
                ToolDefinition(command: "matchprop", label: "Match Properties", icon: .matchProperties)
            ]
        ),
        ToolSection(
            title: "Text",
            featuredTools: [
                ToolDefinition(command: "text", label: "Single Line Text", icon: .text),
                ToolDefinition(command: "mtext", label: "Multiline Text", icon: .multilineText)
            ],
            tools: [
                ToolDefinition(command: "table", label: "Table", icon: .table)
            ]
        ),
        ToolSection(
            title: "Dimension",
            featuredTools: [
                ToolDefinition(command: "dimlinear", label: "Linear", icon: .linearDimension),
                ToolDefinition(command: "dimaligned", label: "Aligned", icon: .alignedDimension)
            ],
            tools: [
                ToolDefinition(command: "dimradius", label: "Radius", icon: .radiusDimension),
                ToolDefinition(command: "dimdiameter", label: "Diameter", icon: .diameterDimension),
                ToolDefinition(command: "dimangular", label: "Angular", icon: .angularDimension),
                ToolDefinition(command: "dimarc", label: "Arc Length", icon: .arcDimension),
                ToolDefinition(command: "dimordinate", label: "Ordinate", icon: .ordinateDimension),
                ToolDefinition(command: "dimbaseline", label: "Baseline", icon: .baselineDimension),
                ToolDefinition(command: "dimcontinue", label: "Continue", icon: .continueDimension),
                ToolDefinition(command: "qdim", label: "Quick Dimension", icon: .quickDimension)
            ]
        ),
        ToolSection(
            title: "Leader",
            featuredTools: [
                ToolDefinition(command: "mleader", label: "Multileader", icon: .multileader)
            ],
            tools: [
                ToolDefinition(command: "mleaderedit", label: "Add Leader", icon: .addLeader),
                ToolDefinition(command: "mleaderedit.remove", label: "Remove Leader", icon: .removeLeader),
                ToolDefinition(command: "mleaderalign", label: "Align Leaders", icon: .alignLeaders)
            ]
        ),
        ToolSection(
            title: "Layers & Properties",
            featuredTools: [],
            tools: [
                ToolDefinition(command: "layer", label: "Layers", icon: .layers),
                ToolDefinition(command: "linetype", label: "Linetype", icon: .linetype),
                ToolDefinition(command: "properties", label: "Properties", icon: .properties),
                ToolDefinition(command: "matchprop", label: "Match", icon: .matchProperties)
            ]
        ),
        ToolSection(
            title: "Measure",
            featuredTools: [],
            tools: [
                ToolDefinition(command: "dist", label: "Distance", icon: .distance),
                ToolDefinition(command: "area", label: "Area", icon: .area),
                ToolDefinition(command: "id", label: "Point ID", icon: .pointID),
                ToolDefinition(command: "list", label: "List", icon: .list)
            ]
        )
    ]
}
