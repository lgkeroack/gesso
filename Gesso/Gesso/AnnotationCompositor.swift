//
//  AnnotationCompositor.swift
//  Gesso
//
//  Builds Image A (screenshot + remaining markup + recognized text overlaid
//  in place of the handwriting it came from) and Text A (a plain-language
//  summary of the recognized notes), from a HandwritingRecognizer result.
//

import Foundation
import UIKit

enum AnnotationCompositor {
    static func composeImage(base: UIImage, markupStrokes: [Stroke], textPlacements: [TextPlacement]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: base.size)
        return renderer.image { context in
            base.draw(at: .zero)

            for stroke in markupStrokes {
                draw(stroke, in: context.cgContext)
            }
            for placement in textPlacements {
                draw(text: placement.text, at: placement.rect)
            }
        }
    }

    static func composeNotesText(_ notes: [String]) -> String {
        guard !notes.isEmpty else {
            return "In addition to the image, the notes are:\n(no handwritten notes recognized)"
        }
        return "In addition to the image, the notes are:\n" + notes.joined(separator: "\n")
    }

    private static func draw(_ stroke: Stroke, in context: CGContext) {
        guard let first = stroke.points.first else { return }
        context.beginPath()
        context.move(to: first)
        for point in stroke.points.dropFirst() {
            context.addLine(to: point)
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch stroke.style {
        case .pen:
            context.setStrokeColor(UIColor.red.cgColor)
            context.setLineWidth(3)
        case .highlighter:
            context.setStrokeColor(UIColor.yellow.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(22)
        }
        context.strokePath()
    }

    private static func draw(text: String, at rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.red,
            .backgroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let origin = CGPoint(x: rect.minX, y: max(0, rect.minY - 20))
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }
}
