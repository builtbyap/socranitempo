//
//  SwipeableJobCardView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct SwipeableJobCardView: View {
    let post: JobPost
    let onApply: () -> Void
    let onPass: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var rotation: Double = 0
    
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Card Background - Fill entire available space
                JobPostCard(post: post, isSaved: false, onToggleSave: {})
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(rotation))
                    .opacity(1.0 - min(abs(dragOffset.width) / (geometry.size.width * 0.5), 0.1))
                    .scaleEffect(1.0 - min(abs(dragOffset.width) / (geometry.size.width * 2), 0.05))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                // Smoother rotation (sorce.jobs style)
                                rotation = Double(value.translation.width / 15)
                            }
                            .onEnded { value in
                                if value.translation.width > swipeThreshold {
                                    // Swipe right - Apply
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = CGSize(width: geometry.size.width * 2.5, height: 0)
                                        rotation = 25
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        onApply()
                                    }
                                } else if value.translation.width < -swipeThreshold {
                                    // Swipe left - Pass
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = CGSize(width: -geometry.size.width * 2.5, height: 0)
                                        rotation = -25
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        onPass()
                                    }
                                } else {
                                    // Snap back (sorce.jobs style - smooth spring)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        dragOffset = .zero
                                        rotation = 0
                                    }
                                }
                            }
                    )
                
                // Swipe Indicators (sorce.jobs style - subtle and clean)
                if abs(dragOffset.width) > 30 {
                    VStack {
                        Spacer()
                        HStack {
                            if dragOffset.width > 0 {
                                // Swipe right - Apply
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.green)
                                    Text("APPLY")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .opacity(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                                .scaleEffect(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                            } else {
                                // Swipe left - Pass
                                VStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.red)
                                    Text("PASS")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .opacity(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                                .scaleEffect(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
        }
    }
}

#Preview {
    SwipeableJobCardView(
        post: JobPost(
            id: "1",
            title: "Software Engineer",
            company: "Tech Corp",
            location: "San Francisco, CA",
            postedDate: "2025-12-01",
            description: "Looking for an experienced software engineer",
            url: "https://example.com/job/1",
            salary: "$120k - $150k",
            jobType: "Full-time",
            sections: nil
        ),
        onApply: {},
        onPass: {}
    )
    .frame(height: 600)
    .padding()
}

