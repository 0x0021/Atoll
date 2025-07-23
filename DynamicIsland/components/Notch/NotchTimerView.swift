//
//  NotchTimerView.swift
//  DynamicIsland
//
//  Timer tab interface for the Dynamic Island
//

import SwiftUI
import Defaults

struct NotchTimerView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.enableTimerFeature) var enableTimerFeature
    
    @AppStorage("customTimerDuration") private var customTimerDuration: Double = 600 // 10 minutes default
    
    var body: some View {
        if enableTimerFeature {
            HStack(alignment: .center, spacing: 32) {
                // Timer Progress and Controls
                timerProgressSection
                
                // Timer Control Panel
                controlsSection
            }
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .blurReplace))
        } else {
            VStack(spacing: 16) {
                Image(systemName: "timer.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                
                Text("Timer Disabled")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Enable timer feature in Settings to use this tab")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var timerProgressSection: some View {
        VStack(spacing: 16) {
            // Circular progress display
            ZStack {
                // Background ring
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(
                        timerManager.currentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: timerManager.progress)
                
                // Timer icon in center
                Image(systemName: "timer")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(timerManager.currentColor)
                    .scaleEffect(timerManager.isRunning && timerManager.isTimerActive ? 1.1 : 1.0)
                    .animation(
                        timerManager.isRunning && timerManager.isTimerActive ? 
                        .easeInOut(duration: 0.3).repeatForever(autoreverses: true) : 
                        .easeInOut(duration: 0.3), 
                        value: timerManager.isRunning && timerManager.isTimerActive
                    )
            }
            
            // Time display
            VStack(spacing: 4) {
                Text(timerManager.formattedTimeRemaining)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(timerManager.isOvertime ? .red : .white)
                
                if timerManager.isTimerActive && timerManager.isPaused {
                    Text("Paused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 20) {
            if timerManager.isTimerActive {
                // Active timer controls
                activeTimerControls
            } else {
                // Quick timer setup
                quickTimerControls
            }
        }
    }
    
    private var activeTimerControls: some View {
        VStack(spacing: 16) {
            if timerManager.isOvertime {
                // Overtime controls - only show stop button
                Button(action: {
                    timerManager.forceStopTimer()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.red)
                        Text("Stop")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 40)
                    .frame(minWidth: 100)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            } else {
                // Normal timer controls
                HStack(spacing: 16) {
                    // Pause/Resume button
                    Button(action: {
                        if timerManager.isPaused {
                            timerManager.resumeTimer()
                        } else {
                            timerManager.pauseTimer()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text(timerManager.isPaused ? "Resume" : "Pause")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(height: 40)
                        .frame(minWidth: 100)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    // Stop button
                    Button(action: {
                        timerManager.stopTimer()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Stop")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(height: 40)
                        .frame(minWidth: 100)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
        }
    }
    
    private var quickTimerControls: some View {
        VStack(spacing: 16) {
            // Quick timer grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    quickTimerButton(minutes: 1, title: "1 min")
                    quickTimerButton(minutes: 5, title: "5 min")
                    quickTimerButton(minutes: 15, title: "15 min")
                }
                
                HStack(spacing: 12) {
                    // Custom timer button
                    Button(action: {
                        timerManager.startTimer(duration: customTimerDuration, name: "Custom Timer")
                    }) {
                        VStack(spacing: 4) {
                            Text(customTimerDisplayText)
                                .font(.system(size: 16, weight: .medium))
                            Text("Custom")
                                .font(.system(size: 12, weight: .regular))
                                .opacity(0.7)
                        }
                        .foregroundStyle(.white)
                        .frame(height: 60)
                        .frame(minWidth: 80)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
        }
        }
    
    private var customTimerDisplayText: String {
        let totalMinutes = Int(customTimerDuration) / 60
        let seconds = Int(customTimerDuration) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes))"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func quickTimerButton(minutes: Int, title: String) -> some View {
        Button(action: {
            timerManager.startTimer(duration: TimeInterval(minutes * 60), name: "\(minutes) Min Timer")
        }) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, height: 60)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    NotchTimerView()
        .environmentObject(DynamicIslandViewModel())
        .frame(width: 500, height: 200)
        .background(.black)
}
