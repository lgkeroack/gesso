//
//  FloatingToolbar.swift
//  Gesso
//
//  Small draggable box (grip handle + pen + eraser + gear) that floats over
//  the WebView within Gesso's own window. Long-press the pen to switch
//  between pen and highlighter styles.
//
//  Pen and eraser are independent, always-visible buttons -- each just
//  selects that tool outright, from any state, so switching between them
//  never requires detouring through Done. Done/Submit is a separate slot
//  that appears alongside them (not in place of them), so leaving a tool
//  or reaching Submit never strands you without a way back into editing.
//  Tapping a tool button that's already active opens its settings popover
//  (size/opacity for pen, size for eraser) instead of doing nothing.
//

import SwiftUI

struct FloatingToolbar: View {
    @Binding var activeTool: ToolMode
    @Binding var annotationStyle: AnnotationStyle
    var hasMarkup: Bool
    var onSubmit: () -> Void
    var onGear: () -> Void

    @AppStorage("penStrokeWidth") private var penStrokeWidth: Double = 3.0
    @AppStorage("penOpacity") private var penOpacity: Double = 1.0
    @AppStorage("eraserRadius") private var eraserRadius: Double = 20.0

    @GestureState private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var showingStylePicker = false
    @State private var showingPenSettings = false
    @State private var showingEraserSettings = false

    var body: some View {
        VStack(spacing: 10) {
            gripHandle

            penButton
            eraserButton
            if activeTool != .none {
                doneButton
            } else if hasMarkup {
                submitButton
            }
            toolButton(systemImage: "gearshape", isActive: false, tint: AppTheme.accent, action: onGear)
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.ink.opacity(0.2), radius: 8, x: 0, y: 4)
        .offset(x: accumulatedOffset.width + dragOffset.width, y: accumulatedOffset.height + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in
                    accumulatedOffset.width += value.translation.width
                    accumulatedOffset.height += value.translation.height
                }
        )
    }

    /// Just exits the active tool -- Pen/Eraser stay visible alongside this,
    /// so leaving a tool never strands the user without a way back in.
    private var doneButton: some View {
        Button(action: { activeTool = .none }) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.success)
                .padding(.horizontal, 8)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    /// Only shown once markup exists and no tool is active -- this is what
    /// actually sends the annotation to the AI. Pen/Eraser stay visible
    /// alongside this too, so it's never a dead end.
    private var submitButton: some View {
        Button(action: onSubmit) {
            Text("Submit")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 8)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    /// Always visible; tapping selects draw mode outright, from any state
    /// (including straight from erasing) -- no toggle-off, no detour through
    /// Done required. Tapping again while already active opens the size/
    /// opacity popover instead of doing nothing.
    private var penButton: some View {
        Button {
            if activeTool == .draw {
                showingPenSettings = true
            } else {
                activeTool = .draw
            }
        } label: {
            Image(systemName: annotationStyle == .highlighter ? "highlighter" : "pencil")
                .font(.title3)
                .foregroundColor(activeTool == .draw ? .white : AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(activeTool == .draw ? AppTheme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            showingStylePicker = true
        }
        .popover(isPresented: $showingStylePicker) {
            VStack(alignment: .leading, spacing: 4) {
                styleOption(title: "Pen", systemImage: "pencil", style: .pen)
                styleOption(title: "Highlighter", systemImage: "highlighter", style: .highlighter)
            }
            .padding(8)
            .presentationCompactAdaptation(.popover)
        }
        .popover(isPresented: $showingPenSettings) {
            penSettingsPanel
        }
    }

    private var penSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Size").font(.caption).foregroundColor(AppTheme.ink.opacity(0.6))
                Slider(value: $penStrokeWidth, in: 1...8, step: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity").font(.caption).foregroundColor(AppTheme.ink.opacity(0.6))
                Slider(value: $penOpacity, in: 0.2...1.0)
            }
        }
        .padding()
        .frame(width: 220)
        .presentationCompactAdaptation(.popover)
    }

    /// Always visible; tapping selects erase mode outright, from any state
    /// (including straight from drawing). Tapping again while already
    /// active opens the size popover instead of doing nothing.
    private var eraserButton: some View {
        Button {
            if activeTool == .erase {
                showingEraserSettings = true
            } else {
                activeTool = .erase
            }
        } label: {
            Image(systemName: "eraser")
                .font(.title3)
                .foregroundColor(activeTool == .erase ? .white : AppTheme.danger)
                .frame(width: 36, height: 36)
                .background(activeTool == .erase ? AppTheme.danger : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingEraserSettings) {
            eraserSettingsPanel
        }
    }

    private var eraserSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Eraser Size").font(.caption).foregroundColor(AppTheme.ink.opacity(0.6))
            Slider(value: $eraserRadius, in: 10...50)
        }
        .padding()
        .frame(width: 220)
        .presentationCompactAdaptation(.popover)
    }

    private func styleOption(title: String, systemImage: String, style: AnnotationStyle) -> some View {
        Button {
            annotationStyle = style
            activeTool = .draw
            showingStylePicker = false
        } label: {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 140, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private var gripHandle: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle().frame(width: 4, height: 4)
                    Circle().frame(width: 4, height: 4)
                }
            }
        }
        .foregroundColor(AppTheme.ink.opacity(0.3))
        .padding(.bottom, 2)
    }

    private func toolButton(systemImage: String, isActive: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(isActive ? .white : tint)
                .frame(width: 36, height: 36)
                .background(isActive ? tint : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FloatingToolbar(activeTool: .constant(.none), annotationStyle: .constant(.pen), hasMarkup: false, onSubmit: {}, onGear: {})
}
