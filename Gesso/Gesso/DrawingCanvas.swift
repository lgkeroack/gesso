//
//  DrawingCanvas.swift
//  Gesso
//
//  Freehand annotation layer drawn on top of the WebView. Pen mode renders a
//  calligraphy fountain-pen line -- width varies with stroke direction, as if
//  drawn with a flat nib held at a fixed angle -- at a width set in Settings.
//  Highlighter mode appends wide translucent strokes. Erase mode removes only
//  the portion of a stroke actually under the eraser, splitting the
//  remainder into separate strokes as needed.
//

import SwiftUI

struct Stroke: Identifiable, Equatable {
    let id = UUID()
    var points: [CGPoint]
    var style: AnnotationStyle
    var penWidth: CGFloat = 3
}

struct DrawingCanvas: View {
    @Binding var strokes: [Stroke]
    @Binding var activeTool: ToolMode
    var annotationStyle: AnnotationStyle

    @AppStorage("penStrokeWidth") private var penStrokeWidth: Double = 3.0
    @State private var currentStrokePoints: [CGPoint] = []

    /// Angle the flat nib is held at; strokes parallel to this read thin,
    /// strokes perpendicular to it read thick -- classic italic-nib look.
    private static let nibAngle: CGFloat = .pi / 4
    /// Floor on the thin end so strokes never taper to invisible.
    private static let calligraphyMinFactor: CGFloat = 0.25

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                draw(stroke.points, style: stroke.style, penWidth: stroke.penWidth, in: context)
            }
            if activeTool == .draw, currentStrokePoints.count > 1 {
                draw(currentStrokePoints, style: annotationStyle, penWidth: CGFloat(penStrokeWidth), in: context)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    switch activeTool {
                    case .draw:
                        currentStrokePoints.append(value.location)
                    case .erase:
                        eraseStrokes(near: value.location)
                    case .none:
                        break
                    }
                }
                .onEnded { _ in
                    if activeTool == .draw, currentStrokePoints.count > 1 {
                        strokes.append(Stroke(points: currentStrokePoints, style: annotationStyle, penWidth: CGFloat(penStrokeWidth)))
                    }
                    currentStrokePoints = []
                }
        )
    }

    private func draw(_ points: [CGPoint], style: AnnotationStyle, penWidth: CGFloat, in context: GraphicsContext) {
        switch style {
        case .pen:
            drawCalligraphy(points, baseWidth: penWidth, in: context)
        case .highlighter:
            context.stroke(
                path(for: points),
                with: .color(.yellow.opacity(0.4)),
                style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// Strokes each segment individually so its width can vary with the
    /// segment's direction relative to the fixed nib angle.
    private func drawCalligraphy(_ points: [CGPoint], baseWidth: CGFloat, in context: GraphicsContext) {
        guard points.count > 1 else { return }
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            guard p0 != p1 else { continue }

            let direction = atan2(p1.y - p0.y, p1.x - p0.x)
            let factor = Self.calligraphyMinFactor
                + (1 - Self.calligraphyMinFactor) * abs(sin(direction - Self.nibAngle))

            var segment = Path()
            segment.move(to: p0)
            segment.addLine(to: p1)
            context.stroke(
                segment,
                with: .color(.red),
                style: StrokeStyle(lineWidth: baseWidth * factor, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func eraseStrokes(near point: CGPoint, radius: CGFloat = 20) {
        strokes = strokes.flatMap { stroke -> [Stroke] in
            let touchesStroke = stroke.points.contains { hypot($0.x - point.x, $0.y - point.y) < radius }
            guard touchesStroke else { return [stroke] }
            return split(stroke, erasingNear: point, radius: radius)
        }
    }

    /// Removes points within `radius` of `point` and returns the surviving
    /// runs as separate strokes, since erasing a gap out of the middle of a
    /// line splits it into disconnected pieces.
    private func split(_ stroke: Stroke, erasingNear point: CGPoint, radius: CGFloat) -> [Stroke] {
        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []
        for p in stroke.points {
            if hypot(p.x - point.x, p.y - point.y) < radius {
                if current.count > 1 { segments.append(current) }
                current = []
            } else {
                current.append(p)
            }
        }
        if current.count > 1 { segments.append(current) }
        return segments.map { Stroke(points: $0, style: stroke.style, penWidth: stroke.penWidth) }
    }
}
