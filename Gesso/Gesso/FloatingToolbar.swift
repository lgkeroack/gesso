//
//  FloatingToolbar.swift
//  Gesso
//
//  Small draggable box (grip handle + pen + eraser + gear) that floats over
//  the WebView within Gesso's own window. Long-press the pen to switch
//  between pen and highlighter styles.
//

import SwiftUI

struct FloatingToolbar: View {
    @Binding var activeTool: ToolMode
    @Binding var annotationStyle: AnnotationStyle
    var onDone: () -> Void
    var onGear: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var showingStylePicker = false

    var body: some View {
        VStack(spacing: 10) {
            gripHandle

            primaryToolButton
            toolButton(systemImage: "eraser", isActive: activeTool == .erase, tint: AppTheme.danger) {
                activeTool = activeTool == .erase ? .none : .erase
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

    @ViewBuilder
    private var primaryToolButton: some View {
        if activeTool == .none {
            penButton
        } else {
            doneButton
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.success)
                .padding(.horizontal, 8)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    private var penButton: some View {
        Button {
            activeTool = activeTool == .draw ? .none : .draw
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
    FloatingToolbar(activeTool: .constant(.none), annotationStyle: .constant(.pen), onDone: {}, onGear: {})
}
