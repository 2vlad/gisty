//
//  LoaderView.swift
//  gisty
//
//  Created by Claude Code on 09.11.2025.
//

import SwiftUI

struct LoaderView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Logo or App Name
                Text("Gisty")
                    .font(.custom("PPNeueMontreal-Bold", size: 48))
                    .foregroundColor(.black)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.custom("PPNeueMontreal-Book", size: 16))
                    .foregroundColor(.gray)
            }
        }
    }
}

