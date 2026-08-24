//
//  DrawingCanvas.swift
//  Gesso
//
//  Freehand annotation layer drawn on top of the WebView. Pen mode appends
//  thin solid strokes, highlighter mode appends wide translucent strokes,
//  and erase mode removes whichever strokes are dragged over, leaving the
//  rest intact.
//

import SwiftUI

struct Stroke: Identifiable, Equatable {
    let id = UUID()
    var points: [CGPoint]
    var style: AnnotationStyle
}

struct DrawingCanvas: View {
    @Binding var strokes: [Stroke]
    @Binding var activeTool: ToolMode
    var annotationStyle: AnnotationStyle

    @State private var currentStrokePoints: [CGPoint] = []

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                draw(stroke.points, style: stroke.style, in: context)
            }
            if activeTool == .draw, currentStrokePoints.count > 1 {
                draw(currentStrokePoints, style: annotationStyle, in: context)
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
                        strokes.append(Stroke(points: currentStrokePoints, style: annotationStyle))
                    }
                    currentStrokePoints = []
                }
        )
    }

    private func draw(_ points: [CGPoint], style: AnnotationStyle, in context: GraphicsContext) {
        let path = path(for: points)
        switch style {
        case .pen:
            context.stroke(path, with: .color(.red), lineWidth: 3)
        case .highlighter:
            context.stroke(
                path,
                with: .color(.yellow.opacity(0.4)),
                style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round)
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
        strokes.removeAll { stroke in
            stroke.points.contains { hypot($0.x - point.x, $0.y - point.y) < radius }
        }
    }
}
