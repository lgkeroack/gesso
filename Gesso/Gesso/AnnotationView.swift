//
//  AnnotationView.swift
//  Gesso
//
//  View for creating and displaying visual annotations
//

import SwiftUI

struct AnnotationView: View {
    @State private var annotations: [Annotation] = []
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            VStack {
                Text("Annotation Canvas")
                    .font(.headline)
                    .padding()
                
                Text("Start annotating UI changes here")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Annotations")
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var position: CGPoint
    var text: String
    var color: Color
}

#Preview {
    NavigationView {
        AnnotationView()
    }
}
