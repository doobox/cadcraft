//! Stable C ABI used by the native ArcWorks macOS application.
//!
//! The bridge deliberately exposes whole commands and immutable render snapshots rather than
//! leaking Rust object layouts across the ABI. JSON is suitable for this first vertical slice;
//! the render snapshot can become a versioned binary buffer without changing the engine itself.
#![allow(unsafe_code)]
#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::unimplemented, clippy::todo, clippy::unreachable)]

use std::ffi::{CStr, CString, c_char};

use cadcraft_color::{Color, Rgb};
use cadcraft_doc::{EntityKind, Handle, Space};
use cadcraft_engine::{
    Input, Session,
    snap::{
        SnapHit,
        tracking::{Acquired, CursorQuery, PathKind, PathShape, Track},
    },
};
use cadcraft_geom::{Ellipse, Vec2};
use cadcraft_render::{DisplayList, Kind, Options};
use serde::Serialize;
use serde_json::json;

pub struct ArcWorksSession {
    engine: Session,
    cursor_snap: Option<SnapHit>,
    autosaver: cadcraft_engine::autosave::Autosaver,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Point {
    x: f32,
    y: f32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ViewState {
    center: Point,
    height: f32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Stroke {
    points: Vec<Point>,
    color: [f32; 4],
    width: f32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TriangleBatch {
    points: Vec<Point>,
    color: [f32; 4],
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot {
    title: String,
    path: Option<String>,
    dirty: bool,
    undo_label: Option<String>,
    redo_label: Option<String>,
    clipboard_serial: Option<u64>,
    prompt: String,
    history: Vec<String>,
    entity_count: usize,
    selection_count: usize,
    can_window_select: bool,
    bounds: [f32; 4],
    view: ViewState,
    strokes: Vec<Stroke>,
    triangles: Vec<TriangleBatch>,
    grips: Vec<Grip>,
    drafting: DraftingState,
    layouts: Vec<String>,
    current_layout: String,
    annotation_scales: Vec<String>,
    current_annotation_scale: String,
    layers: Vec<LayerSummary>,
    linetypes: Vec<String>,
    linetype_library: Vec<String>,
    layer_states: Vec<String>,
    has_active_viewport: bool,
    selection_types: Vec<SelectionType>,
    property_groups: Vec<PropertyGroup>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct LayerSummary {
    name: String,
    color_name: String,
    color_hex: String,
    on: bool,
    frozen: bool,
    locked: bool,
    plot: bool,
    linetype: String,
    lineweight: String,
    transparency: u8,
    description: String,
    plot_style: String,
    new_viewport_frozen: bool,
    viewport_frozen: Option<bool>,
    viewport_color_name: Option<String>,
    viewport_color_hex: Option<String>,
    used: bool,
    current: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SelectionType {
    name: String,
    count: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PropertyGroup {
    name: String,
    rows: Vec<PropertyRow>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PropertyRow {
    key: String,
    label: String,
    kind: String,
    value_json: String,
    varies: bool,
    display: String,
    editable: bool,
    options: Vec<PropertyOption>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PropertyOption {
    label: String,
    value_json: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct DraftingState {
    object_snap: bool,
    ortho: bool,
    polar: bool,
    grid: bool,
    snap: bool,
    dynamic_input: bool,
    object_snap_tracking: bool,
    grid_spacing: Point,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Grip {
    handle: String,
    index: usize,
    point: Point,
}

fn property_kind(kind: cadcraft_engine::properties::Kind) -> &'static str {
    use cadcraft_engine::properties::Kind;
    match kind {
        Kind::Text => "text",
        Kind::Contents => "contents",
        Kind::Number => "number",
        Kind::Distance => "distance",
        Kind::Angle => "angle",
        Kind::Bool => "bool",
        Kind::Choice => "choice",
        Kind::Color => "color",
        Kind::Layer => "layer",
        Kind::Linetype => "linetype",
        Kind::Lineweight => "lineweight",
        Kind::Transparency => "transparency",
        Kind::TextStyle => "textStyle",
        Kind::DimStyle => "dimStyle",
    }
}

fn property_row(key: &str, label: &str, kind: &str, value: serde_json::Value, editable: bool) -> PropertyRow {
    let display = match (kind, &value) {
        ("bool", serde_json::Value::Bool(true)) => "Yes".to_string(),
        ("bool", serde_json::Value::Bool(false)) => "No".to_string(),
        (_, serde_json::Value::String(text)) => text.clone(),
        (_, serde_json::Value::Null) => String::new(),
        (_, other) => other.to_string(),
    };
    PropertyRow {
        key: key.to_string(),
        label: label.to_string(),
        kind: kind.to_string(),
        value_json: value.to_string(),
        varies: false,
        display,
        editable,
        options: Vec::new(),
    }
}

fn geometry_group(document: &cadcraft_doc::Drawing, selection: &[Handle]) -> Option<PropertyGroup> {
    if selection.len() != 1 {
        return None;
    }
    let entity = document.entity(selection[0])?;
    let mut rows = Vec::new();
    match &entity.kind {
        EntityKind::Line(line) => {
            let delta = line.b.xy() - line.a.xy();
            rows.extend([
                property_row("startX", "Start X", "distance", json!(line.a.x), true),
                property_row("startY", "Start Y", "distance", json!(line.a.y), true),
                property_row("endX", "End X", "distance", json!(line.b.x), true),
                property_row("endY", "End Y", "distance", json!(line.b.y), true),
                property_row("deltaX", "Delta X", "distance", json!(delta.x), false),
                property_row("deltaY", "Delta Y", "distance", json!(delta.y), false),
                property_row("length", "Length", "distance", json!(delta.len()), true),
                property_row("angle", "Angle", "angle", json!(delta.angle().to_degrees()), true),
            ]);
        }
        EntityKind::Circle(circle) => {
            rows.extend([
                property_row("centerX", "Center X", "distance", json!(circle.center.x), true),
                property_row("centerY", "Center Y", "distance", json!(circle.center.y), true),
                property_row("radius", "Radius", "distance", json!(circle.radius), true),
                property_row("diameter", "Diameter", "distance", json!(circle.radius * 2.0), true),
                property_row("circumference", "Circumference", "distance", json!(circle.radius * std::f64::consts::TAU), true),
                property_row("area", "Area", "number", json!(circle.radius * circle.radius * std::f64::consts::PI), true),
            ]);
        }
        EntityKind::Arc(arc) => {
            rows.extend([
                property_row("centerX", "Center X", "distance", json!(arc.center.x), true),
                property_row("centerY", "Center Y", "distance", json!(arc.center.y), true),
                property_row("radius", "Radius", "distance", json!(arc.radius), true),
                property_row("startAngle", "Start angle", "angle", json!(arc.start.to_degrees()), true),
                property_row("endAngle", "End angle", "angle", json!(arc.end.to_degrees()), true),
            ]);
        }
        EntityKind::LwPolyline(polyline) => {
            let geometry = cadcraft_geom::Polyline { vertices: polyline.vertices.clone(), closed: polyline.closed };
            rows.extend([
                property_row("width", "Global width", "distance", json!(polyline.const_width), true),
                property_row("length", "Length", "distance", json!(geometry.len()), false),
                property_row("closed", "Closed", "bool", json!(polyline.closed), true),
            ]);
            if polyline.closed {
                rows.push(property_row("area", "Area", "number", json!(geometry.area().abs()), false));
            }
        }
        EntityKind::Hatch(hatch) => {
            rows.extend([
                property_row("pattern", "Pattern", "text", json!(hatch.pattern), true),
                property_row("scale", "Scale", "number", json!(hatch.scale), true),
                property_row("angle", "Angle", "angle", json!(hatch.angle.to_degrees()), true),
            ]);
        }
        EntityKind::Insert(insert) => {
            rows.extend([
                property_row("blockName", "Name", "text", json!(insert.block), false),
                property_row("positionX", "Position X", "distance", json!(insert.insert.x), false),
                property_row("positionY", "Position Y", "distance", json!(insert.insert.y), false),
                property_row("positionZ", "Position Z", "distance", json!(insert.insert.z), false),
                property_row("rotation", "Rotation", "angle", json!(insert.rotation.to_degrees()), true),
                property_row("scale", "Scale", "number", json!(insert.scale.x), true),
            ]);
        }
        _ => {}
    }
    (!rows.is_empty()).then(|| PropertyGroup { name: "Geometry".to_string(), rows })
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct CursorFeedback {
    point: Point,
    snap: Option<String>,
    base: Option<Point>,
    distance: Option<f32>,
    angle_degrees: Option<f32>,
    strokes: Vec<Stroke>,
    triangles: Vec<TriangleBatch>,
    tracking_guides: Vec<TrackingGuide>,
    acquired_points: Vec<AcquiredPoint>,
    inference: Option<String>,
    tracking_crossing: bool,
    tracking_wait: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TrackingGuide {
    points: Vec<Point>,
    kind: &'static str,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct AcquiredPoint {
    point: Point,
    parallel: bool,
}

fn point(value: Vec2) -> Point {
    Point { x: value.x as f32, y: value.y as f32 }
}

fn tracking_feedback(track: Option<&Track>, acquired: &[Acquired], far: f64) -> (Vec<TrackingGuide>, Vec<AcquiredPoint>, Option<String>, bool) {
    let acquired_points =
        acquired.iter().map(|item| AcquiredPoint { point: point(item.at()), parallel: matches!(item, Acquired::Parallel { .. }) }).collect();
    let Some(track) = track else {
        return (Vec::new(), acquired_points, None, false);
    };

    let mut guides = Vec::with_capacity(track.paths.len());
    let mut labels = Vec::with_capacity(track.paths.len() + usize::from(track.object.is_some()));
    for path in &track.paths {
        let points = match path.shape {
            PathShape::Ray { origin, dir } => {
                let back = (track.point - origin).dot(dir).clamp(0.0, far);
                vec![point(track.point - dir * back), point(track.point + dir * far)]
            }
            PathShape::Line { dir, .. } => vec![point(track.point - dir * far), point(track.point + dir * far)],
            PathShape::Circle { center, radius, .. } => {
                let angle = center.angle_to(track.point);
                let span = (far / radius).min(std::f64::consts::PI);
                (0..=96).map(|index| point(Vec2::polar(center, radius, angle - span + span * f64::from(index) / 48.0))).collect()
            }
            PathShape::Ellipse { center, major, ratio, .. } => {
                let ellipse = Ellipse::full(center, major, ratio);
                let parameter = ellipse.param_of(track.point);
                let span = (far / (major.len() * ratio.min(1.0))).min(std::f64::consts::PI);
                (0..=96).map(|index| point(ellipse.at_param(parameter - span + span * f64::from(index) / 48.0))).collect()
            }
        };
        let kind = match path.kind {
            PathKind::Polar => "polar",
            PathKind::Alignment => "alignment",
            PathKind::Extension => "extension",
            PathKind::Parallel => "parallel",
            PathKind::Apparent => "apparent",
        };
        guides.push(TrackingGuide { points, kind });
        let distance = cadcraft_engine::units::format_distance(path.from.dist(track.point), 2, 4);
        let angle = (path.from.angle_to(track.point).to_degrees().round() as i64).rem_euclid(360);
        labels.push(format!("{}: {distance} < {angle}°", path.name));
    }
    if let Some(object) = track.object {
        labels.push(object.to_string());
    }
    let crossing = track.paths.len() > 1 || track.object.is_some();
    (guides, acquired_points, Some(labels.join(", ")), crossing)
}

fn color(r: Rgb, alpha: u8) -> [f32; 4] {
    [f32::from(r.0) / 255.0, f32::from(r.1) / 255.0, f32::from(r.2) / 255.0, f32::from(alpha) / 255.0]
}

fn points(list: &DisplayList, primitive: &cadcraft_render::DPrim) -> Vec<Point> {
    list.points(primitive).iter().map(|point| Point { x: point.x as f32, y: point.y as f32 }).collect()
}

fn primitives(list: &DisplayList, background: Rgb, selection: &[cadcraft_doc::Handle], preview: bool) -> (Vec<Stroke>, Vec<TriangleBatch>) {
    let mut strokes = Vec::new();
    let mut triangles = Vec::new();
    for primitive in &list.prims {
        let selected = selection.contains(&primitive.handle);
        let rgba = if preview {
            [0.25, 0.78, 1.0, 0.9]
        } else if selected {
            [0.22, 0.68, 1.0, 1.0]
        } else {
            color(primitive.display_rgb(background), primitive.alpha())
        };
        match primitive.kind {
            Kind::Polyline => strokes.push(Stroke {
                points: points(list, primitive),
                color: rgba,
                width: if selected { primitive.lw.max(0.5) } else { primitive.lw.max(0.25) },
            }),
            Kind::Tris => triangles.push(TriangleBatch { points: points(list, primitive), color: rgba }),
            Kind::Mask if !preview => {
                triangles.push(TriangleBatch { points: points(list, primitive), color: color(background, u8::MAX) });
            }
            Kind::Mask => {}
            Kind::Point => {
                let Some(point) = list.points(primitive).first() else { continue };
                let radius = list.bounds.width().max(list.bounds.height()).max(1.0) * 0.002;
                strokes.push(Stroke {
                    points: vec![
                        Point { x: (point.x - radius) as f32, y: point.y as f32 },
                        Point { x: (point.x + radius) as f32, y: point.y as f32 },
                    ],
                    color: rgba,
                    width: 0.25,
                });
                strokes.push(Stroke {
                    points: vec![
                        Point { x: point.x as f32, y: (point.y - radius) as f32 },
                        Point { x: point.x as f32, y: (point.y + radius) as f32 },
                    ],
                    color: rgba,
                    width: 0.25,
                });
            }
            Kind::Infinite { .. } => {}
        }
    }
    (strokes, triangles)
}

fn snapshot(session: &Session) -> Result<Snapshot, String> {
    let document = session.doc().map_err(|error| error.to_string())?;
    let space: Space = session.layout_space();
    let list = cadcraft_render::build(document, &space, &Options::default());
    let background = Rgb(28, 30, 34);
    let selection = session.selection();
    let (strokes, triangles) = primitives(&list, background, &selection, false);
    let bounds = if list.bounds.is_empty() {
        [-10.0, -10.0, 10.0, 10.0]
    } else {
        [list.bounds.min.x as f32, list.bounds.min.y as f32, list.bounds.max.x as f32, list.bounds.max.y as f32]
    };
    let state = session.state().map_err(|error| error.to_string())?;
    let view = state.view();
    let settings = session.drafting_settings();
    let mut layouts: Vec<_> = document.layouts.iter().collect();
    layouts.sort_by_key(|layout| layout.tab_order);
    let current_layout = match &space {
        Space::Model => "Model".to_string(),
        Space::Paper(name) => name.clone(),
    };
    let current_layer = document.header.str("CLAYER", "0");
    let used_layers = cadcraft_engine::cmd::layer::used_layers(document);
    let active_viewport = state.active_viewport().map(|(_, viewport)| viewport);
    let layers = document
        .layers
        .iter()
        .map(|layer| LayerSummary {
            name: layer.name.clone(),
            color_name: layer.color.name(),
            color_hex: layer.color.resolve(Color::Index(7), Color::Index(7)).hex(),
            on: layer.on,
            frozen: layer.frozen,
            locked: layer.locked,
            plot: layer.plot,
            linetype: layer.linetype.clone(),
            lineweight: layer.lineweight.name(),
            transparency: layer.transparency,
            description: layer.description.clone(),
            plot_style: layer.plot_style.clone(),
            new_viewport_frozen: layer.vp_freeze_new,
            viewport_frozen: active_viewport
                .as_ref()
                .map(|viewport| viewport.frozen_layers.iter().any(|name| name.eq_ignore_ascii_case(&layer.name))),
            viewport_color_name: active_viewport.as_ref().and_then(|viewport| {
                viewport.layer_colors.iter().find(|(name, _)| name.eq_ignore_ascii_case(&layer.name)).map(|(_, color)| color.name())
            }),
            viewport_color_hex: active_viewport.as_ref().and_then(|viewport| {
                viewport
                    .layer_colors
                    .iter()
                    .find(|(name, _)| name.eq_ignore_ascii_case(&layer.name))
                    .map(|(_, color)| color.resolve(Color::Index(7), Color::Index(7)).hex())
            }),
            used: used_layers.contains(&layer.name.to_ascii_lowercase()),
            current: layer.name.eq_ignore_ascii_case(&current_layer),
        })
        .collect();
    let description = cadcraft_engine::properties::describe(document, &selection, None);
    let selection_types = description.types.into_iter().map(|value| SelectionType { name: value.name.to_string(), count: value.count }).collect();
    let mut property_groups: Vec<PropertyGroup> = description
        .groups
        .into_iter()
        .map(|group| PropertyGroup {
            name: group.name.to_string(),
            rows: group
                .rows
                .into_iter()
                .take(50)
                .map(|row| PropertyRow {
                    key: row.key.to_string(),
                    label: row.label.to_string(),
                    kind: property_kind(row.kind).to_string(),
                    value_json: row.value.to_string(),
                    varies: row.varies,
                    display: row.display,
                    editable: row.editable,
                    options: row
                        .options
                        .into_iter()
                        .map(|option| PropertyOption { label: option.label, value_json: option.value.to_string() })
                        .collect(),
                })
                .collect(),
        })
        .collect();
    if let Some(group) = geometry_group(document, &selection) {
        property_groups.push(group);
    }
    let grips = if session.shows_grips(selection.len()) {
        selection
            .iter()
            .take(100)
            .flat_map(|handle| {
                session.grips_of(*handle).unwrap_or_default().into_iter().enumerate().map(|(index, point)| Grip {
                    handle: handle.hex(),
                    index,
                    point: Point { x: point.x as f32, y: point.y as f32 },
                })
            })
            .collect()
    } else {
        Vec::new()
    };
    Ok(Snapshot {
        title: state.title.clone(),
        path: state.path.clone(),
        dirty: state.is_dirty(),
        undo_label: state.undo.last().map(|snapshot| snapshot.label.clone()),
        redo_label: state.redo.last().map(|snapshot| snapshot.label.clone()),
        clipboard_serial: session.clipboard_source.as_ref().map(|source| source.serial),
        prompt: session.current_prompt().map(|prompt| prompt.display()).unwrap_or_else(|| "Command:".into()),
        history: session.log.iter().rev().take(80).cloned().collect::<Vec<_>>().into_iter().rev().collect(),
        entity_count: document.entity_count(),
        selection_count: session.selection().len(),
        can_window_select: session.picking_objects(),
        bounds,
        view: ViewState { center: Point { x: view.center.x as f32, y: view.center.y as f32 }, height: view.height as f32 },
        strokes,
        triangles,
        grips,
        drafting: DraftingState {
            object_snap: settings.osmode & cadcraft_engine::snap::mode::OFF == 0,
            ortho: settings.orthomode,
            polar: settings.polarmode,
            grid: settings.gridmode,
            snap: settings.snapmode,
            dynamic_input: settings.dynmode,
            object_snap_tracking: settings.otrack,
            grid_spacing: Point { x: settings.gridunit.x as f32, y: settings.gridunit.y as f32 },
        },
        layouts: layouts.into_iter().map(|layout| layout.name.clone()).collect(),
        current_layout,
        annotation_scales: document.scales.iter().map(|scale| scale.name.clone()).collect(),
        current_annotation_scale: document.current_anno_scale().name.clone(),
        layers,
        linetypes: document.linetypes.iter().map(|linetype| linetype.name.clone()).collect(),
        linetype_library: cadcraft_doc::library::standard_linetypes().into_iter().map(|linetype| linetype.name).collect(),
        layer_states: document.layer_states.iter().map(|state| state.name.clone()).collect(),
        has_active_viewport: active_viewport.is_some(),
        selection_types,
        property_groups,
    })
}

fn response(value: serde_json::Value) -> *mut c_char {
    let text = value.to_string().replace('\0', "�");
    CString::new(text).map_or(std::ptr::null_mut(), CString::into_raw)
}

fn error(message: impl Into<String>) -> *mut c_char {
    response(json!({ "ok": false, "error": message.into() }))
}

fn set_selection_property(session: &mut ArcWorksSession, key: &str, value: serde_json::Value) -> Result<(), String> {
    let selection = session.engine.selection();
    if selection.is_empty() {
        return Err("nothing selected".to_string());
    }
    let document = session.engine.doc().map_err(|error| error.to_string())?;
    let described = cadcraft_engine::properties::describe(document, &selection, None);
    let described_editable = described.groups.iter().flat_map(|group| &group.rows).any(|row| row.key == key && row.editable);
    let geometry_editable =
        geometry_group(document, &selection).is_some_and(|group| group.rows.into_iter().any(|row| row.key == key && row.editable));
    if !described_editable && !geometry_editable {
        return Err(format!("property `{key}` is not editable for this selection"));
    }

    let (actual_key, actual_value) = match key {
        "startX" | "startY" | "endX" | "endY" | "centerX" | "centerY" => {
            let number = value.as_f64().ok_or_else(|| format!("{key} must be a number"))?;
            let entity = document.entity(selection[0]).ok_or_else(|| "the selected object is unavailable".to_string())?;
            match (&entity.kind, key) {
                (EntityKind::Line(line), "startX") => ("start", json!([number, line.a.y])),
                (EntityKind::Line(line), "startY") => ("start", json!([line.a.x, number])),
                (EntityKind::Line(line), "endX") => ("end", json!([number, line.b.y])),
                (EntityKind::Line(line), "endY") => ("end", json!([line.b.x, number])),
                (EntityKind::Circle(circle), "centerX") => ("center", json!([number, circle.center.y])),
                (EntityKind::Circle(circle), "centerY") => ("center", json!([circle.center.x, number])),
                (EntityKind::Arc(arc), "centerX") => ("center", json!([number, arc.center.y])),
                (EntityKind::Arc(arc), "centerY") => ("center", json!([arc.center.x, number])),
                _ => return Err(format!("property `{key}` is unavailable for this object")),
            }
        }
        _ => (key, value),
    };
    let mut parameters = serde_json::Map::new();
    parameters.insert(actual_key.to_string(), actual_value);
    session.engine.execute("properties.set", &serde_json::Value::Object(parameters)).map(|_| ()).map_err(|error| error.to_string())
}

fn with_session<T>(ptr: *mut ArcWorksSession, operation: impl FnOnce(&mut ArcWorksSession) -> Result<T, String>) -> Result<T, String> {
    if ptr.is_null() {
        return Err("ArcWorks engine session is unavailable".into());
    }
    // SAFETY: pointers are created by `arcworks_session_new`, owned by Swift's EngineSession,
    // and released once by `arcworks_session_free`. Calls are confined to the main actor.
    let session = unsafe { ptr.as_mut() }.ok_or_else(|| "ArcWorks engine session is unavailable".to_string())?;
    operation(session)
}

fn viewport_size(width: f64, height: f64) -> Result<(f64, f64), String> {
    if !(width.is_finite() && height.is_finite() && width > 0.0 && height > 0.0) {
        return Err("the viewport size must be finite and positive".to_string());
    }
    Ok((width, height))
}

fn pan_view(engine: &mut Session, screen_x: f64, screen_y: f64, viewport_width: f64, viewport_height: f64) -> Result<(), String> {
    if !(screen_x.is_finite() && screen_y.is_finite()) {
        return Err("the pan distance must be finite".to_string());
    }
    let (width, height) = viewport_size(viewport_width, viewport_height)?;
    engine.viewport_px = (width, height);
    let state = engine.state_mut().map_err(|error| error.to_string())?;
    let view = state.view();
    let world_per_point = view.height / height;
    state.set_view_quiet(cadcraft_engine::View {
        center: view.center - Vec2::new(screen_x * world_per_point, screen_y * world_per_point),
        height: view.height,
    });
    Ok(())
}

fn zoom_view_at_screen(
    engine: &mut Session,
    factor: f64,
    screen_x: f64,
    screen_y: f64,
    viewport_width: f64,
    viewport_height: f64,
) -> Result<(), String> {
    if !(factor.is_finite() && factor > 0.0 && screen_x.is_finite() && screen_y.is_finite()) {
        return Err("the zoom factor and position must be finite and the factor must be positive".to_string());
    }
    let (width, height) = viewport_size(viewport_width, viewport_height)?;
    engine.viewport_px = (width, height);
    let about = {
        let view = engine.state().map_err(|error| error.to_string())?.view();
        let visible_width = view.height * width / height;
        Vec2::new(view.center.x + (screen_x / width - 0.5) * visible_width, view.center.y + (screen_y / height - 0.5) * view.height)
    };
    engine.zoom_about(factor, about).map_err(|error| error.to_string())
}

fn c_text(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() {
        return Err("command text is missing".into());
    }
    // SAFETY: Swift supplies a temporary NUL-terminated UTF-8 buffer for the duration of the call.
    let text = unsafe { CStr::from_ptr(ptr) }.to_str().map_err(|_| "command text is not UTF-8")?;
    Ok(text.to_string())
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_new() -> *mut ArcWorksSession {
    let result = std::panic::catch_unwind(|| {
        install_io();
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        Box::into_raw(Box::new(ArcWorksSession {
            engine,
            cursor_snap: None,
            autosaver: cadcraft_engine::autosave::Autosaver::new(cadcraft_engine::autosave::instance_id()),
        }))
    });
    result.unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_command_catalog() -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        let commands = cadcraft_engine::command_specs()
            .iter()
            .filter(|command| !command.id.contains('.') && !matches!(command.id, "3dorbit" | "3dpoly"))
            .map(|command| {
                json!({
                    "id": command.id,
                    "label": command.label,
                    "aliases": command.aliases,
                    "shortcut": command.shortcut,
                })
            })
            .collect::<Vec<_>>();
        json!({ "ok": true, "commands": commands })
    });
    match result {
        Ok(value) => response(value),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

fn install_io() {
    cadcraft_engine::cmd::file::set_io(cadcraft_engine::cmd::file::IoHooks {
        read: |bytes, name| cadcraft_io::read(bytes, name).map_err(|error| error.to_string()),
        write: |drawing, name| cadcraft_io::write(drawing, name).map_err(|error| error.to_string()),
        plot: None,
    });
    cadcraft_engine::cmd::file::set_write_as(|drawing, name, options| {
        cadcraft_io::write_with(drawing, name, &cadcraft_io::SaveOptions { version: options.version, binary: options.binary })
            .map_err(|error| error.to_string())
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_new_drawing(ptr: *mut ArcWorksSession, metric: bool) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.cursor_snap = None;
            session.engine.execute("new", &json!({ "metric": metric })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_open(ptr: *mut ArcWorksSession, path: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        with_session(ptr, |session| {
            session.cursor_snap = None;
            session.engine.execute("open", &json!({ "path": path })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_save(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| session.engine.execute("qsave", &json!({})).map(|_| ()).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_save_as(ptr: *mut ArcWorksSession, path: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        with_session(ptr, |session| session.engine.execute("saveas", &json!({ "path": path })).map(|_| ()).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_export(ptr: *mut ArcWorksSession, path: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        with_session(ptr, |session| session.engine.execute("export", &json!({ "path": path })).map(|_| ()).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `ptr` must be null or a live pointer returned by [`arcworks_session_new`]. It must not be
/// passed to this function more than once.
pub unsafe extern "C" fn arcworks_session_free(ptr: *mut ArcWorksSession) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: ownership of a pointer returned by `arcworks_session_new` is returned exactly once.
    let mut session = unsafe { Box::from_raw(ptr) };
    session.autosaver.shutdown();
    drop(session);
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_autosave_configure(ptr: *mut ArcWorksSession, path: *const c_char, minutes: u32) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        cadcraft_engine::autosave::set_savefilepath(&path);
        cadcraft_engine::autosave::set_savetime(minutes);
        let recoveries = with_session(ptr, |session| {
            let directory = std::path::Path::new(&path);
            cadcraft_engine::autosave::prune_locks(directory);
            Ok(cadcraft_engine::autosave::recoverable(directory, &session.autosaver.instance))
        })?;
        Ok::<_, String>(json!({ "ok": true, "recoveries": recoveries }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_autosave_tick(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.autosaver.tick(&session.engine);
            Ok(())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_recover(ptr: *mut ArcWorksSession, path: *const c_char, title: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        let title = c_text(title)?;
        with_session(ptr, |session| {
            session.cursor_snap = None;
            let value =
                session.engine.execute("recover", &json!({ "path": path, "copy": true, "title": title })).map_err(|error| error.to_string())?;
            if let Some(uid) = value.get("uid").and_then(serde_json::Value::as_u64) {
                session.autosaver.adopt(&session.engine, uid, &path);
            }
            Ok(())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_discard_recovery(ptr: *mut ArcWorksSession, path: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let path = c_text(path)?;
        with_session(ptr, |_| {
            cadcraft_engine::autosave::discard(&path);
            Ok(())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_autosave_shutdown(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.autosaver.shutdown();
            Ok(())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_command(ptr: *mut ArcWorksSession, command: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let command = c_text(command)?;
        with_session(ptr, |session| session.engine.cmdline(&command).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_clipboard_text(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let clipboard_text = with_session(ptr, |session| Ok(cadcraft_engine::cmd::clipboard::system_text(&session.engine)))?;
        Ok::<_, String>(json!({ "ok": true, "clipboardText": clipboard_text }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_load_clipboard(ptr: *mut ArcWorksSession, text: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let text = c_text(text)?;
        let loaded = with_session(ptr, |session| Ok(cadcraft_engine::cmd::clipboard::load_system_text(&mut session.engine, &text)))?;
        if !loaded {
            return Err("the clipboard does not contain an ArcWorks drawing selection".to_string());
        }
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_view_pan(
    ptr: *mut ArcWorksSession,
    screen_x: f64,
    screen_y: f64,
    viewport_width: f64,
    viewport_height: f64,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| pan_view(&mut session.engine, screen_x, screen_y, viewport_width, viewport_height))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_view_zoom(
    ptr: *mut ArcWorksSession,
    factor: f64,
    screen_x: f64,
    screen_y: f64,
    viewport_width: f64,
    viewport_height: f64,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| zoom_view_at_screen(&mut session.engine, factor, screen_x, screen_y, viewport_width, viewport_height))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_zoom_extents(ptr: *mut ArcWorksSession, viewport_width: f64, viewport_height: f64) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let (width, height) = viewport_size(viewport_width, viewport_height)?;
        with_session(ptr, |session| {
            session.engine.viewport_px = (width, height);
            session.engine.zoom_extents().map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_point(
    ptr: *mut ArcWorksSession,
    x: f64,
    y: f64,
    shift: bool,
    viewport_width: f64,
    viewport_height: f64,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.engine.viewport_px = (viewport_width.max(1.0), viewport_height.max(1.0));
            let raw_point = Vec2::new(x, y);
            match session.engine.current_prompt() {
                Some(prompt) if prompt.accept.point => {
                    if let Some(hit) = session.cursor_snap.take() {
                        session.engine.input_snapped(hit).map_err(|error| error.to_string())
                    } else {
                        session.engine.input(Input::Point(session.engine.cursor)).map_err(|error| error.to_string())
                    }
                }
                Some(_) => Ok(()),
                None => session.engine.idle_click(raw_point, shift).map_err(|error| error.to_string()),
            }
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_cursor(
    ptr: *mut ArcWorksSession,
    x: f64,
    y: f64,
    shift: bool,
    world_per_pixel: f64,
    viewport_width: f64,
    viewport_height: f64,
    now: f64,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let feedback = with_session(ptr, |session| {
            session.engine.viewport_px = (viewport_width.max(1.0), viewport_height.max(1.0));
            let raw = Vec2::new(x, y);
            let prompt = session.engine.current_prompt();
            let snapped = if let Some(prompt) = prompt.as_ref().filter(|prompt| prompt.accept.point) {
                let aperture = session.engine.drafting_settings().aperture.max(1.0) * world_per_pixel.max(f64::EPSILON);
                session.engine.snap_cursor(
                    raw,
                    &CursorQuery {
                        base: prompt.base,
                        deferred: prompt.deferred,
                        corner: prompt.corner,
                        aperture,
                        tol: 6.0 * world_per_pixel.max(f64::EPSILON),
                        now,
                        shift,
                    },
                )
            } else {
                session.engine.tracking.clear();
                Default::default()
            };
            let far = viewport_width.max(viewport_height).max(1.0) * world_per_pixel.max(f64::EPSILON) * 2.0;
            let (tracking_guides, acquired_points, inference, tracking_crossing) =
                tracking_feedback(snapped.track.as_ref(), &session.engine.tracking.acquired, far);
            let point = if prompt.as_ref().is_some_and(|prompt| prompt.accept.point) { snapped.point } else { raw };
            session.cursor_snap = snapped.snap;
            session.engine.cursor = point;
            session.engine.cursor_deferred = session.cursor_snap.and_then(|hit| hit.deferred);

            let preview = session.engine.preview(point);
            let document = session.engine.doc().map_err(|error| error.to_string())?;
            let list = cadcraft_render::build_entities(document, preview.iter(), &Options::default());
            let (strokes, triangles) = primitives(&list, Rgb(28, 30, 34), &[], true);
            let dynamic_base = prompt.as_ref().and_then(|value| value.base).filter(|_| session.engine.drafting_settings().dynmode);
            let (base, distance, angle_degrees) = dynamic_base.map_or((None, None, None), |base| {
                let delta = point - base;
                let angle = delta.y.atan2(delta.x).to_degrees().rem_euclid(360.0);
                (Some(Point { x: base.x as f32, y: base.y as f32 }), Some(delta.len() as f32), Some(angle as f32))
            });
            Ok(CursorFeedback {
                point: Point { x: point.x as f32, y: point.y as f32 },
                snap: session.cursor_snap.map(|hit| hit.name.to_string()),
                base,
                distance,
                angle_degrees,
                strokes,
                triangles,
                tracking_guides,
                acquired_points,
                inference,
                tracking_crossing,
                tracking_wait: snapped.wait,
            })
        })?;
        serde_json::to_value(feedback).map(|value| json!({ "ok": true, "cursor": value })).map_err(|error| error.to_string())
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_drafting_toggle(ptr: *mut ArcWorksSession, setting: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let setting = c_text(setting)?;
        if !matches!(setting.as_str(), "osnap" | "ortho" | "polar" | "grid" | "snap" | "dynmode" | "otrack") {
            return Err(format!("unsupported drafting setting: {setting}"));
        }
        with_session(ptr, |session| session.engine.execute(&setting, &json!({})).map(|_| ()).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_set_current_layer(ptr: *mut ArcWorksSession, name: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let name = c_text(name)?;
        with_session(ptr, |session| {
            session.engine.execute("layer.current", &json!({ "name": name })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_set_layout(ptr: *mut ArcWorksSession, name: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let name = c_text(name)?;
        with_session(ptr, |session| session.engine.execute("layout.set", &json!({ "name": name })).map(|_| ()).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_create_layout(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            let created = session.engine.execute("layout.new", &json!({})).map_err(|error| error.to_string())?;
            let name = created.get("name").and_then(serde_json::Value::as_str).ok_or_else(|| "the new layout has no name".to_string())?;
            session.engine.execute("layout.set", &json!({ "name": name })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_set_annotation_scale(ptr: *mut ArcWorksSession, name: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let name = c_text(name)?;
        with_session(ptr, |session| {
            session.engine.execute("setvar", &json!({ "name": "CANNOSCALE", "value": name })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_set_selection_layer(ptr: *mut ArcWorksSession, name: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let name = c_text(name)?;
        with_session(ptr, |session| {
            session.engine.execute("properties.set", &json!({ "layer": name })).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_set_selection_property(ptr: *mut ArcWorksSession, key: *const c_char, value_json: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let key = c_text(key)?;
        let value_json = c_text(value_json)?;
        let value = serde_json::from_str(&value_json).map_err(|error| format!("invalid property value: {error}"))?;
        with_session(ptr, |session| set_selection_property(session, &key, value))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_layer_action(
    ptr: *mut ArcWorksSession,
    action: *const c_char,
    name: *const c_char,
    value: *const c_char,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let action = c_text(action)?;
        let name = c_text(name)?;
        let value = c_text(value)?;
        with_session(ptr, |session| {
            let params = match action.as_str() {
                "new" => ("layer.new", json!({ "name": name })),
                "rename" => ("layer.set", json!({ "name": name, "newName": value })),
                "color" => ("layer.set", json!({ "name": name, "color": value })),
                "delete" => ("layer.delete", json!({ "name": name })),
                "linetype" => ("layer.set", json!({ "name": name, "linetype": value })),
                "lineweight" => {
                    let lineweight = value.parse::<f64>().map_or_else(|_| json!(value), |number| json!(number));
                    ("layer.set", json!({ "name": name, "lineweight": lineweight }))
                }
                "transparency" => {
                    let transparency = value.parse::<u8>().map_err(|_| "transparency must be between 0 and 90".to_string())?;
                    ("layer.set", json!({ "name": name, "transparency": transparency.min(90) }))
                }
                "description" => ("layer.set", json!({ "name": name, "description": value })),
                "plotStyle" => ("layer.set", json!({ "name": name, "plotStyle": value })),
                "loadLinetype" => ("linetype", json!({ "load": name })),
                "saveState" => ("layerstate.save", json!({ "name": name })),
                "restoreState" => ("layerstate.restore", json!({ "name": name })),
                "deleteState" => ("layerstate.delete", json!({ "name": name })),
                "renameState" => ("layerstate.rename", json!({ "from": name, "to": value })),
                "viewportColor" | "clearViewportColor" | "toggleViewportFrozen" => {
                    let (handle, viewport) = session
                        .engine
                        .state()
                        .map_err(|error| error.to_string())?
                        .active_viewport()
                        .ok_or_else(|| "activate a paper-space viewport first".to_string())?;
                    match action.as_str() {
                        "viewportColor" => ("vplayer", json!({ "handle": handle, "colors": { (name): value } })),
                        "clearViewportColor" => ("vplayer", json!({ "handle": handle, "colors": { (name): null } })),
                        "toggleViewportFrozen" => {
                            let is_frozen = viewport.frozen_layers.iter().any(|item| item.eq_ignore_ascii_case(&name));
                            if is_frozen {
                                ("vplayer", json!({ "handle": handle, "thaw": [name] }))
                            } else {
                                ("vplayer", json!({ "handle": handle, "freeze": [name] }))
                            }
                        }
                        _ => return Err(format!("unsupported layer action: {action}")),
                    }
                }
                "toggleOn" | "toggleFrozen" | "toggleLocked" | "togglePlot" | "toggleNewViewportFrozen" => {
                    let layer = session
                        .engine
                        .doc()
                        .map_err(|error| error.to_string())?
                        .layer(&name)
                        .cloned()
                        .ok_or_else(|| format!("layer `{name}` is unavailable"))?;
                    match action.as_str() {
                        "toggleOn" => ("layer.set", json!({ "name": name, "on": !layer.on })),
                        "toggleFrozen" => ("layer.set", json!({ "name": name, "frozen": !layer.frozen })),
                        "toggleLocked" => ("layer.set", json!({ "name": name, "locked": !layer.locked })),
                        "togglePlot" => ("layer.set", json!({ "name": name, "plot": !layer.plot })),
                        "toggleNewViewportFrozen" => ("layer.set", json!({ "name": name, "newVpFreeze": !layer.vp_freeze_new })),
                        _ => return Err(format!("unsupported layer action: {action}")),
                    }
                }
                _ => return Err(format!("unsupported layer action: {action}")),
            };
            session.engine.execute(params.0, &params.1).map(|_| ()).map_err(|error| error.to_string())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_window(
    ptr: *mut ArcWorksSession,
    start_x: f64,
    start_y: f64,
    end_x: f64,
    end_y: f64,
    shift: bool,
    viewport_width: f64,
    viewport_height: f64,
) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.engine.viewport_px = (viewport_width.max(1.0), viewport_height.max(1.0));
            let start = Vec2::new(start_x, start_y);
            let end = Vec2::new(end_x, end_y);
            if !session.engine.begin_window(start) {
                return Ok(());
            }
            if session.engine.current_prompt().is_some() {
                session.engine.input(Input::Point(end)).map_err(|error| error.to_string())
            } else {
                session.engine.idle_click(end, shift).map_err(|error| error.to_string())
            }
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_begin_grip(ptr: *mut ArcWorksSession, handle: *const c_char, index: usize) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let handle = c_text(handle)?;
        let handle = Handle::parse_hex(&handle).ok_or_else(|| "the grip object is unavailable".to_string())?;
        with_session(ptr, |session| session.engine.start_grip_edit(&[(handle, index)]).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_enter(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| session.engine.input(Input::Enter).map_err(|error| error.to_string()))?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_cancel(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        with_session(ptr, |session| {
            session.engine.cancel();
            Ok(())
        })?;
        Ok::<_, String>(json!({ "ok": true }))
    }));
    match result {
        Ok(Ok(value)) => response(value),
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn arcworks_session_snapshot(ptr: *mut ArcWorksSession) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| with_session(ptr, |session| snapshot(&session.engine))));
    match result {
        Ok(Ok(snapshot)) => match serde_json::to_value(snapshot) {
            Ok(value) => response(json!({ "ok": true, "snapshot": value })),
            Err(serialize_error) => error(serialize_error.to_string()),
        },
        Ok(Err(message)) => error(message),
        Err(_) => error("the Rust engine recovered from an unexpected failure"),
    }
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `ptr` must be null or a live string pointer returned by another `arcworks_*` function. It
/// must not be passed to this function more than once.
pub unsafe extern "C" fn arcworks_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: this pointer came from `CString::into_raw` in this library and is released once.
    unsafe { drop(CString::from_raw(ptr)) };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sample_drawing_produces_native_render_data() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);

        let result = snapshot(&engine);
        assert!(result.is_ok());
        if let Ok(snapshot) = result {
            assert_eq!(snapshot.title, "ArcWorks Sample");
            assert!(snapshot.entity_count > 0);
            assert!(!snapshot.strokes.is_empty());
            assert!(snapshot.bounds[2] > snapshot.bounds[0]);
            assert!(snapshot.bounds[3] > snapshot.bounds[1]);
        }
    }

    #[test]
    fn snapshot_uses_the_engine_view_without_refitting_after_geometry_changes() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        engine.state_mut().expect("drawing state").set_view_quiet(cadcraft_engine::View { center: Vec2::new(12.0, 8.0), height: 20.0 });

        let before = snapshot(&engine).expect("initial snapshot").view;
        assert!(engine.cmdline("line").is_ok());
        assert!(engine.input(Input::Point(Vec2::new(1_000.0, 1_000.0))).is_ok());
        assert!(engine.input(Input::Point(Vec2::new(1_100.0, 1_100.0))).is_ok());
        assert!(engine.input(Input::Enter).is_ok());
        let after = snapshot(&engine).expect("updated snapshot").view;

        assert_eq!((before.center.x, before.center.y, before.height), (after.center.x, after.center.y, after.height));
    }

    #[test]
    fn native_view_navigation_updates_the_engine_camera() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        engine.state_mut().expect("drawing state").set_view_quiet(cadcraft_engine::View { center: Vec2::new(10.0, 20.0), height: 40.0 });

        assert!(pan_view(&mut engine, 100.0, 50.0, 1_000.0, 500.0).is_ok());
        assert_eq!(engine.state().expect("panned state").view(), cadcraft_engine::View { center: Vec2::new(2.0, 16.0), height: 40.0 });

        assert!(zoom_view_at_screen(&mut engine, 2.0, 750.0, 250.0, 1_000.0, 500.0).is_ok());
        assert_eq!(engine.state().expect("zoomed state").view(), cadcraft_engine::View { center: Vec2::new(12.0, 16.0), height: 20.0 });
    }

    #[test]
    fn native_view_navigation_rejects_hostile_numbers() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);

        assert!(pan_view(&mut engine, f64::NAN, 0.0, 800.0, 600.0).is_err());
        assert!(zoom_view_at_screen(&mut engine, f64::INFINITY, 0.0, 0.0, 800.0, 600.0).is_err());
        assert!(zoom_view_at_screen(&mut engine, 1.0, 0.0, 0.0, 0.0, 600.0).is_err());
    }

    #[test]
    fn snapshot_tracks_layout_tabs_and_annotation_scale() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);

        let initial = snapshot(&engine).expect("sample snapshot");
        assert_eq!(initial.current_layout, "Model");
        assert!(!initial.layouts.is_empty());
        assert!(initial.annotation_scales.contains(&initial.current_annotation_scale));

        let created = engine.execute("layout.new", &json!({})).expect("create layout");
        let name = created["name"].as_str().expect("layout name");
        engine.execute("layout.set", &json!({ "name": name })).expect("switch layout");

        let updated = snapshot(&engine).expect("updated snapshot");
        assert_eq!(updated.current_layout, name);
        assert!(updated.layouts.iter().any(|layout| layout == name));

        if let Some(scale) = updated.annotation_scales.iter().find(|scale| *scale != &updated.current_annotation_scale).cloned() {
            engine.execute("setvar", &json!({ "name": "CANNOSCALE", "value": scale })).expect("change annotation scale");
            assert_eq!(snapshot(&engine).expect("scaled snapshot").current_annotation_scale, scale);
        }
    }

    #[test]
    fn drawings_save_and_reopen_through_the_native_file_layer() {
        install_io();
        let path = std::env::temp_dir().join(format!("arcworks-roundtrip-{}.dxf", std::process::id()));
        let path_text = path.to_string_lossy().into_owned();
        let result = (|| -> Result<(usize, usize, bool, bool), String> {
            let mut source = Session::empty();
            source.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
            let expected = source.doc().map_err(|error| error.to_string())?.entity_count();
            source.execute("saveas", &json!({ "path": &path_text })).map_err(|error| error.to_string())?;
            let saved = source.state().map_err(|error| error.to_string())?;

            let mut reopened = Session::empty();
            reopened.execute("open", &json!({ "path": &path_text })).map_err(|error| error.to_string())?;
            let reopened_count = reopened.doc().map_err(|error| error.to_string())?.entity_count();
            Ok((expected, reopened_count, saved.path.as_deref() == Some(path_text.as_str()), saved.is_dirty()))
        })();
        let _ = std::fs::remove_file(&path);

        assert!(matches!(result, Ok((expected, reopened, true, false)) if expected > 0 && expected == reopened));
    }

    #[test]
    fn drawings_export_to_svg_without_becoming_the_saved_file() {
        install_io();
        let path = std::env::temp_dir().join(format!("arcworks-export-{}.svg", std::process::id()));
        let path_text = path.to_string_lossy().into_owned();
        let result = (|| -> Result<(bool, bool), String> {
            let mut engine = Session::empty();
            engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
            engine.execute("export", &json!({ "path": &path_text })).map_err(|error| error.to_string())?;
            let svg = std::fs::read_to_string(&path).map_err(|error| error.to_string())?;
            let state = engine.state().map_err(|error| error.to_string())?;
            Ok((svg.contains("<svg"), state.path.is_none()))
        })();
        let _ = std::fs::remove_file(&path);

        assert_eq!(result, Ok((true, true)));
    }

    #[test]
    fn point_inputs_create_geometry() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        let before = engine.doc().map_or(0, cadcraft_doc::Drawing::entity_count);

        assert!(engine.cmdline("line").is_ok());
        assert!(engine.input(Input::Point(Vec2::new(20.0, 20.0))).is_ok());
        assert!(engine.input(Input::Point(Vec2::new(25.0, 20.0))).is_ok());
        assert!(engine.input(Input::Enter).is_ok());

        let after = engine.doc().map_or(0, cadcraft_doc::Drawing::entity_count);
        assert_eq!(after, before + 1);
        assert!(engine.idle_click(Vec2::new(22.5, 20.0), false).is_ok());
        assert_eq!(engine.selection().len(), 1);
    }

    #[test]
    fn snapshot_reports_native_undo_and_redo_actions() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        assert!(snapshot(&engine).is_ok_and(|value| value.undo_label.is_none() && value.redo_label.is_none()));

        assert!(engine.cmdline("line").is_ok());
        assert!(engine.input(Input::Point(Vec2::new(20.0, 20.0))).is_ok());
        assert!(engine.input(Input::Point(Vec2::new(25.0, 20.0))).is_ok());
        assert!(engine.input(Input::Enter).is_ok());
        assert!(snapshot(&engine).is_ok_and(|value| value.undo_label.as_deref() == Some("Line") && value.redo_label.is_none()));

        assert!(engine.cmdline("u").is_ok());
        assert!(snapshot(&engine).is_ok_and(|value| value.undo_label.is_none() && value.redo_label.as_deref() == Some("Line")));

        assert!(engine.cmdline("redo").is_ok());
        assert!(snapshot(&engine).is_ok_and(|value| value.undo_label.as_deref() == Some("Line") && value.redo_label.is_none()));
    }

    #[test]
    fn native_edit_actions_share_drawing_objects_through_clipboard_text() {
        install_io();
        let mut source = Session::empty();
        source.open_drawing(cadcraft_engine::sample::default_sample(), "Source", None);
        let source_count = source.doc().map_or(0, cadcraft_doc::Drawing::entity_count);
        assert!(source.execute("selectall", &json!({})).is_ok());
        assert_eq!(source.selection().len(), source_count);
        assert!(source.execute("copyclip", &json!({})).is_ok());
        let clipboard_text = cadcraft_engine::cmd::clipboard::system_text(&source);
        assert!(clipboard_text.is_some());

        let mut destination = Session::empty();
        destination.open_drawing(cadcraft_doc::Drawing::new_metric(), "Destination", None);
        let loaded = clipboard_text.as_deref().is_some_and(|text| cadcraft_engine::cmd::clipboard::load_system_text(&mut destination, text));
        assert!(loaded);
        assert!(destination.execute("pasteclip", &json!({ "at": [0.0, 0.0] })).is_ok());
        assert_eq!(destination.doc().map_or(0, cadcraft_doc::Drawing::entity_count), source_count);

        assert!(source.execute("erase.selection", &json!({})).is_ok());
        assert_eq!(source.doc().map_or(0, cadcraft_doc::Drawing::entity_count), 0);
        assert!(source.execute("u", &json!({})).is_ok());
        assert_eq!(source.doc().map_or(0, cadcraft_doc::Drawing::entity_count), source_count);
    }

    #[test]
    fn selected_properties_and_geometry_are_editable() {
        let mut session = ArcWorksSession {
            engine: Session::empty(),
            cursor_snap: None,
            autosaver: cadcraft_engine::autosave::Autosaver::new(cadcraft_engine::autosave::instance_id()),
        };
        session.engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        assert!(session.engine.cmdline("line").is_ok());
        assert!(session.engine.input(Input::Point(Vec2::new(20.0, 20.0))).is_ok());
        assert!(session.engine.input(Input::Point(Vec2::new(25.0, 20.0))).is_ok());
        assert!(session.engine.input(Input::Enter).is_ok());
        assert!(session.engine.idle_click(Vec2::new(22.5, 20.0), false).is_ok());

        assert!(set_selection_property(&mut session, "color", json!(1)).is_ok());
        assert!(set_selection_property(&mut session, "length", json!(10.0)).is_ok());
        let updated = snapshot(&session.engine);
        assert!(updated.is_ok_and(|value| {
            let rows = value.property_groups.iter().flat_map(|group| &group.rows);
            rows.clone().any(|row| row.key == "color" && row.display == "Red")
                && rows.into_iter().any(|row| row.key == "length" && row.value_json == "10.0")
        }));
    }

    #[test]
    fn active_line_produces_a_native_rubber_band() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);

        assert!(engine.cmdline("line").is_ok());
        assert!(engine.input(Input::Point(Vec2::new(20.0, 20.0))).is_ok());
        let preview = engine.preview(Vec2::new(25.0, 22.0));
        let document = engine.doc();

        assert!(!preview.is_empty());
        assert!(document.is_ok());
        if let Ok(document) = document {
            let list = cadcraft_render::build_entities(document, preview.iter(), &Options::default());
            let (strokes, triangles) = primitives(&list, Rgb(28, 30, 34), &[], true);
            assert!(!strokes.is_empty() || !triangles.is_empty());
        }
    }

    #[test]
    fn tracking_results_produce_native_guides_and_acquisition_markers() {
        let track = Track {
            point: Vec2::new(8.0, 3.0),
            paths: vec![cadcraft_engine::snap::tracking::Path {
                shape: PathShape::Ray { origin: Vec2::new(2.0, 3.0), dir: Vec2::new(1.0, 0.0) },
                kind: PathKind::Alignment,
                from: Vec2::new(2.0, 3.0),
                name: "Endpoint",
            }],
            object: None,
        };
        let acquired = [Acquired::Temporary { at: Vec2::new(2.0, 3.0) }];

        let (guides, points, inference, crossing) = tracking_feedback(Some(&track), &acquired, 20.0);

        assert_eq!(guides.len(), 1);
        assert_eq!(guides[0].kind, "alignment");
        assert_eq!(guides[0].points.len(), 2);
        assert_eq!(points.len(), 1);
        assert!(!points[0].parallel);
        assert!(inference.is_some_and(|value| value.contains("Endpoint: 6.0000 < 0°")));
        assert!(!crossing);
    }

    #[test]
    fn window_selection_exposes_editable_grips() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);

        assert!(engine.begin_window(Vec2::new(-100.0, -100.0)));
        assert!(engine.idle_click(Vec2::new(100.0, 100.0), false).is_ok());
        let result = snapshot(&engine);

        assert!(result.is_ok());
        if let Ok(snapshot) = result {
            assert!(snapshot.selection_count > 0);
            assert!(!snapshot.grips.is_empty());
            assert!(!snapshot.selection_types.is_empty());
            assert!(!snapshot.property_groups.is_empty());
        }
    }

    #[test]
    fn drafting_settings_are_exposed_and_toggle_through_the_engine() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        let before = snapshot(&engine).map(|value| value.drafting.ortho);

        assert!(before.is_ok());
        assert!(engine.execute("ortho", &json!({})).is_ok());

        let after = snapshot(&engine).map(|value| value.drafting.ortho);
        assert_eq!(before.ok().map(|value| !value), after.ok());
    }

    #[test]
    fn layer_table_exposes_and_changes_the_current_layer() {
        let mut engine = Session::empty();
        engine.open_drawing(cadcraft_engine::sample::default_sample(), "ArcWorks Sample", None);
        let result = snapshot(&engine);

        assert!(result.is_ok());
        if let Ok(snapshot) = result {
            assert!(!snapshot.layers.is_empty());
            assert_eq!(snapshot.layers.iter().filter(|layer| layer.current).count(), 1);
            if let Some(layer) = snapshot.layers.iter().find(|layer| !layer.current) {
                assert!(engine.execute("layer.current", &json!({ "name": layer.name })).is_ok());
                let updated = super::snapshot(&engine);
                assert!(updated.is_ok_and(|value| value.layers.iter().any(|item| item.current && item.name == layer.name)));
            }
        }

        assert!(engine.execute("layer.new", &json!({ "name": "ArcWorks Test" })).is_ok());
        assert!(
            engine.execute("layer.set", &json!({ "name": "ArcWorks Test", "newName": "ArcWorks Renamed", "color": "3", "locked": true }),).is_ok()
        );
        let updated = snapshot(&engine);
        assert!(updated.is_ok_and(|value| {
            value.layers.iter().any(|layer| layer.name == "ArcWorks Renamed" && layer.locked && layer.color_hex == "#00ff00")
        }));
        assert!(engine.execute("layer.delete", &json!({ "name": "ArcWorks Renamed" })).is_ok());
    }
}
