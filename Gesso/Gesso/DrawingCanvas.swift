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
//  Touch input goes through PencilAwareTouchView (UIKit) rather than a
//  SwiftUI gesture, since SwiftUI's DragGesture has no concept of touch type
//  and can't tell an Apple Pencil touch from a resting palm -- the two would
//  otherwise fight over the same gesture and produce jumping, erratic lines.
//
//  Stroke.points are stored in the web page's content coordinate space (view
//  point + scroll offset at the moment they're drawn), not view space, so
//  markup stays pinned to the page content when the user scrolls. Rendering
//  and erase hit-testing convert back to the *current* view space by
//  subtracting the live scroll offset every frame.
//

import SwiftUI

struct Stroke: Identifiable, Equatable {
    let id = UUID()
    var points: [CGPoint]
    var style: AnnotationStyle
    var penWidth: CGFloat = 3
    var penOpacity: CGFloat = 1
}

struct DrawingCanvas: View {
    @Binding var strokes: [Stroke]
    @Binding var activeTool: ToolMode
    var annotationStyle: AnnotationStyle
    /// The WebView's current scroll position (webView.scrollView.contentOffset).
    var scrollOffset: CGPoint

    @AppStorage("penStrokeWidth") private var penStrokeWidth: Double = 3.0
    @AppStorage("penOpacity") private var penOpacity: Double = 1.0
    @AppStorage("eraserRadius") private var eraserRadius: Double = 20.0
    @State private var currentStrokePoints: [CGPoint] = []

    /// Angle the flat nib is held at; strokes parallel to this read thin,
    /// strokes perpendicular to it read thick -- classic italic-nib look.
    private static let nibAngle: CGFloat = .pi / 4
    /// Floor on the thin end so strokes never taper to invisible.
    private static let calligraphyMinFactor: CGFloat = 0.25

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                draw(stroke.points.map(toView), style: stroke.style, penWidth: stroke.penWidth, penOpacity: stroke.penOpacity, in: context)
            }
            if activeTool == .draw, currentStrokePoints.count > 1 {
                draw(currentStrokePoints.map(toView), style: annotationStyle, penWidth: CGFloat(penStrokeWidth), penOpacity: CGFloat(penOpacity), in: context)
            }
        }
        .overlay(
            PencilAwareTouchArea(
                onChanged: { viewPoint in
                    let point = toContent(viewPoint)
                    switch activeTool {
                    case .draw:
                        currentStrokePoints.append(point)
                    case .erase:
                        eraseStrokes(near: point, radius: CGFloat(eraserRadius))
                    case .none:
                        break
                    }
                },
                onEnded: {
                    if activeTool == .draw, currentStrokePoints.count > 1 {
                        strokes.append(Stroke(
                            points: currentStrokePoints,
                            style: annotationStyle,
                            penWidth: CGFloat(penStrokeWidth),
                            penOpacity: CGFloat(penOpacity)
                        ))
                    }
                    currentStrokePoints = []
                }
            )
        )
    }

    private func toContent(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x + scrollOffset.x, y: viewPoint.y + scrollOffset.y)
    }

    private func toView(_ contentPoint: CGPoint) -> CGPoint {
        CGPoint(x: contentPoint.x - scrollOffset.x, y: contentPoint.y - scrollOffset.y)
    }

    private func draw(_ points: [CGPoint], style: AnnotationStyle, penWidth: CGFloat, penOpacity: CGFloat, in context: GraphicsContext) {
        switch style {
        case .pen:
            drawCalligraphy(points, baseWidth: penWidth, opacity: penOpacity, in: context)
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
    private func drawCalligraphy(_ points: [CGPoint], baseWidth: CGFloat, opacity: CGFloat, in context: GraphicsContext) {
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
                with: .color(.red.opacity(opacity)),
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

    private func eraseStrokes(near point: CGPoint, radius: CGFloat) {
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
        return segments.map { Stroke(points: $0, style: stroke.style, penWidth: stroke.penWidth, penOpacity: stroke.penOpacity) }
    }
}

/// Bridges raw UIKit touches into a single-point stream, rejecting palm
/// touches while the Apple Pencil is in use.
private struct PencilAwareTouchArea: UIViewRepresentable {
    var onChanged: (CGPoint) -> Void
    var onEnded: () -> Void

    func makeUIView(context: Context) -> PencilAwareTouchView {
        let view = PencilAwareTouchView()
        view.onChanged = onChanged
        view.onEnded = onEnded
        return view
    }

    func updateUIView(_ uiView: PencilAwareTouchView, context: Context) {
        uiView.onChanged = onChanged
        uiView.onEnded = onEnded
    }
}

/// Tracks at most one touch at a time: an Apple Pencil touch always takes
/// over from whatever else is active, and once a pencil touch is down, any
/// concurrent finger touch (a resting palm) is ignored outright rather than
/// competing with it for the same stroke.
private final class PencilAwareTouchView: UIView {
    var onChanged: ((CGPoint) -> Void)?
    var onEnded: (() -> Void)?

    private weak var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let pencilTouch = touches.first(where: { $0.type == .pencil }) {
            activeTouch = pencilTouch
        } else if activeTouch == nil, let touch = touches.first {
            activeTouch = touch
        }
        report()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        report()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        onEnded?()
    }

    private func report() {
        guard let activeTouch else { return }
        onChanged?(activeTouch.location(in: self))
    }
}
