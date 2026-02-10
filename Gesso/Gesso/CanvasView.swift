//
//  CanvasView.swift
//  Gesso
//
//  Main canvas view for real-time UI interaction
//

import SwiftUI

struct CanvasView: View {
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray.opacity(0.3), width: 1)
                
                // Content area
                VStack {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("Canvas Area")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
            )
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    // Reset view
                    scale = 1.0
                    offset = .zero
                }) {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CanvasView()
    }
}
