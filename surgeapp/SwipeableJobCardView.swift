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
                // Card Background
                JobPostCard(post: post, isSaved: false, onToggleSave: {})
                    .offset(dragOffset)
                    .rotationEffect(.degrees(rotation))
                    .opacity(dragOffset.width == 0 ? 1.0 : 0.95)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                rotation = Double(value.translation.width / 20)
                            }
                            .onEnded { value in
                                if value.translation.width > swipeThreshold {
                                    // Swipe right - Apply
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = CGSize(width: geometry.size.width * 2, height: 0)
                                        rotation = 30
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onApply()
                                    }
                                } else if value.translation.width < -swipeThreshold {
                                    // Swipe left - Pass
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = CGSize(width: -geometry.size.width * 2, height: 0)
                                        rotation = -30
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onPass()
                                    }
                                } else {
                                    // Snap back
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                        rotation = 0
                                    }
                                }
                            }
                    )
                
                // Swipe Indicators
                if abs(dragOffset.width) > 20 {
                    VStack {
                        Spacer()
                        HStack {
                            if dragOffset.width > 0 {
                                // Swipe right - Apply
                                VStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.green)
                                    Text("APPLY")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .opacity(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                            } else {
                                // Swipe left - Pass
                                VStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.red)
                                    Text("PASS")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .opacity(min(abs(dragOffset.width) / swipeThreshold, 1.0))
                            }
                        }
                        .padding(.bottom, 100)
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
            jobType: "Full-time"
        ),
        onApply: {},
        onPass: {}
    )
    .frame(height: 600)
    .padding()
}

