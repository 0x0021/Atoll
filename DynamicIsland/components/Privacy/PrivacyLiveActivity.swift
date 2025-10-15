//
//  PrivacyLiveActivity.swift
//  DynamicIsland
//
//  Created for camera and microphone privacy indicators
//

import SwiftUI
import Defaults

struct PrivacyLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject var recordingManager = ScreenRecordingManager.shared
    @State private var isHovering: Bool = false
    @State private var gestureProgress: CGFloat = 0
    @State private var isExpanded: Bool = false
    
    // Calculate if both camera and mic are active
    private var bothIndicatorsActive: Bool {
        privacyManager.indicatorLayout.showsCameraIndicator && 
        privacyManager.indicatorLayout.showsMicrophoneIndicator
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Recording pulsator OR microphone (if both indicators active without recording)
            Color.clear
                .background {
                    if isExpanded {
                        HStack {
                            if recordingManager.isRecording {
                                // Recording pulsator
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red.opacity(0.15))
                                    
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .modifier(PulsingModifier())
                                }
                                .frame(width: vm.effectiveClosedNotchHeight - 12, height: vm.effectiveClosedNotchHeight - 12)
                            } else if bothIndicatorsActive {
                                // Microphone on left when both active and no recording
                                PrivacyIcon(type: .microphone)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                }
                .frame(width: isExpanded && (recordingManager.isRecording || bothIndicatorsActive) ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2 + 20) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
            
            // Center - Black fill
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0))
            
            // Right side - Privacy indicators
            Color.clear
                .background {
                    if isExpanded {
                        HStack(spacing: 4) {
                            // When both active without recording: only camera on right (mic is on left)
                            // When recording + both: show both on right
                            // When only one active: show that one
                            
                            if bothIndicatorsActive && recordingManager.isRecording {
                                // Both indicators on right when recording
                                PrivacyIcon(type: .microphone)
                                PrivacyIcon(type: .camera)
                            } else if bothIndicatorsActive {
                                // Only camera on right when both active (mic is on left)
                                PrivacyIcon(type: .camera)
                            } else {
                                // Single indicator
                                if privacyManager.indicatorLayout.showsMicrophoneIndicator {
                                    PrivacyIcon(type: .microphone)
                                }
                                if privacyManager.indicatorLayout.showsCameraIndicator {
                                    PrivacyIcon(type: .camera)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2 + 20) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0))
        .onAppear {
            withAnimation(.smooth(duration: 0.4)) {
                isExpanded = true
            }
        }
        .onChange(of: privacyManager.hasAnyIndicator) { _, newValue in
            if !newValue {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = false
                }
            } else {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = true
                }
            }
        }
    }
}

// Individual privacy icon component
struct PrivacyIcon: View {
    let type: PrivacyIndicatorType
    @State private var isPulsing = false
    
    // Color based on type: camera = #26CC41, mic = #FF9402
    private var iconColor: Color {
        type == .camera ? Color(red: 0.152, green: 0.804, blue: 0.256) : Color(red: 1.000, green: 0.584, blue: 0.010)
    }
    
    var body: some View {
        // Simple icon without blur/glow effects
        Image(systemName: type.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: 24, height: 24)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.85)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
