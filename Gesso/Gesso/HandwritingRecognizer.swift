//
//  HandwritingRecognizer.swift
//  Gesso
//
//  Groups nearby pen strokes into candidate phrases and runs Apple's
//  on-device handwriting recognition (Vision) on each group. The merge
//  distance is wide enough to bridge normal word-to-word spacing within a
//  written phrase (so "delete this banner" recognizes as one note, not
//  three), while staying well short of the distance to a separate
//  annotation written elsewhere on the screen. A group that isn't
//  confidently recognized as text is left as a visual markup stroke.
//  Highlighter strokes are never treated as text -- a highlight is always
//  a mark, not handwriting.
//

import Foundation
import UIKit
import Vision

struct TextPlacement {
    let text: String
    let rect: CGRect
}

struct AnnotationRecognitionResult {
    var recognizedNotes: [String]
    var markupStrokes: [Stroke]
    var textPlacements: [TextPlacement]
}

enum HandwritingRecognizer {
    static func process(strokes: [Stroke]) async -> AnnotationRecognitionResult {
        let penStrokes = strokes.filter { $0.style == .pen }
        let otherStrokes = strokes.filter { $0.style != .pen }

        let clusters = cluster(penStrokes)

        var recognizedNotes: [String] = []
        var markupStrokes = otherStrokes
        var textPlacements: [TextPlacement] = []

        for strokeCluster in clusters {
            if let text = await recognizeText(in: strokeCluster) {
                recognizedNotes.append(text)
                textPlacements.append(TextPlacement(text: text, rect: boundingBox(of: strokeCluster)))
            } else {
                markupStrokes.append(contentsOf: strokeCluster)
            }
        }

        return AnnotationRecognitionResult(
            recognizedNotes: recognizedNotes,
            markupStrokes: markupStrokes,
            textPlacements: textPlacements
        )
    }

    /// Merges strokes whose (padded) bounding boxes overlap into groups, so a
    /// multi-word phrase gets recognized (and later joined) as one unit
    /// rather than each word being clustered, recognized, and sent
    /// separately.
    private static func cluster(_ strokes: [Stroke], padding: CGFloat = 60) -> [[Stroke]] {
        var remaining = strokes
        var clusters: [[Stroke]] = []

        while let first = remaining.first {
            var currentCluster = [first]
            remaining.removeFirst()

            var didExpand = true
            while didExpand {
                didExpand = false
                let clusterBox = boundingBox(of: currentCluster).insetBy(dx: -padding, dy: -padding)
                var index = 0
                while index < remaining.count {
                    if clusterBox.intersects(boundingBox(of: [remaining[index]])) {
                        currentCluster.append(remaining.remove(at: index))
                        didExpand = true
                    } else {
                        index += 1
                    }
                }
            }
            clusters.append(currentCluster)
        }
        return clusters
    }

    private static func boundingBox(of strokes: [Stroke]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for stroke in strokes {
            for point in stroke.points {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
        }
        guard minX <= maxX, minY <= maxY else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func recognizeText(in strokes: [Stroke]) async -> String? {
        let box = boundingBox(of: strokes).insetBy(dx: -10, dy: -10)
        guard box.width > 4, box.height > 4 else { return nil }

        let scale: CGFloat = 4
        let size = CGSize(width: box.width * scale, height: box.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let cg = context.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(3 * scale)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                cg.beginPath()
                cg.move(to: CGPoint(x: (first.x - box.minX) * scale, y: (first.y - box.minY) * scale))
                for point in stroke.points.dropFirst() {
                    cg.addLine(to: CGPoint(x: (point.x - box.minX) * scale, y: (point.y - box.minY) * scale))
                }
                cg.strokePath()
            }
        }

        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first }
                    .filter { $0.confidence >= 0.3 }
                    .map(\.string)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
