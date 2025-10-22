//
//  LockScreenLiveActivity.swift
//  DynamicIsland
//
//  Created for lock screen live activity
//

import SwiftUI
import Defaults

struct LockScreenLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @StateObject private var iconAnimator = LockIconAnimator(initiallyLocked: LockScreenManager.shared.isLocked)
    @State private var isHovering: Bool = false
    @State private var gestureProgress: CGFloat = 0
    @State private var isExpanded: Bool = false

    private var iconColor: Color {
        .white
    }
    
    private var indicatorDimension: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left - Lock icon with subtle glow
            Color.clear
                .overlay(alignment: .leading) {
                    if isExpanded {
                        LockIconProgressView(progress: iconAnimator.progress, iconColor: iconColor)
                            .frame(width: indicatorDimension, height: indicatorDimension)
                    }
                }
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
            
            // Center - Black fill
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0))
            
            // Right - Empty for symmetry with animation
            Color.clear
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0))
        .onAppear {
            iconAnimator.update(isLocked: lockScreenManager.isLocked, animated: false)
            // Expand immediately without animation to avoid conflicts
            withAnimation(.smooth(duration: 0.4)) {
                isExpanded = true
            }
        }
        .onDisappear {
            // Collapse immediately when removed from hierarchy
            isExpanded = false
        }
        .onChange(of: lockScreenManager.isLockIdle) { _, newValue in
            if newValue {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = false
                }
            } else {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = true
                }
            }
        }
        .onChange(of: lockScreenManager.isLocked) { _, newValue in
            iconAnimator.update(isLocked: newValue)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lockScreenManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: isExpanded)
    }
}
