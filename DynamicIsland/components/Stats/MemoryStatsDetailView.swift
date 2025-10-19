//
//  MemoryStatsDetailView.swift
//  DynamicIsland
//
//  Detailed memory dashboard mirroring the Stats app layout.
//
//  Created by GitHub Copilot on 19/10/2025.
//

import SwiftUI

struct MemoryStatsDetailView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @State private var topProcesses: [ProcessStats] = []
    
    private let accentColor = Color.green
    private let cardBackground = Color(nsColor: .windowBackgroundColor).opacity(0.65)
    private let processDisplayLimit = 8
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatsCard(title: "Memory Overview", padding: 16, background: cardBackground, cornerRadius: 12) {
                    MemoryUsageDashboard(breakdown: statsManager.memoryBreakdown, accentColor: accentColor)
                }
                
                StatsCard(title: "Top Processes", padding: 16, background: cardBackground, cornerRadius: 12) {
                    CPUProcessList(processes: topProcesses, accentColor: accentColor, displayLimit: processDisplayLimit)
                }

                StatsCard(title: "Pressure & Swap", padding: 16, background: cardBackground, cornerRadius: 12) {
                    MemoryHealthView(breakdown: statsManager.memoryBreakdown, accentColor: accentColor)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 380, minHeight: 420)
        .onAppear(perform: refreshProcesses)
        .onReceive(statsManager.$lastUpdated) { _ in
            refreshProcesses()
        }
    }
    
    private func refreshProcesses() {
        let processes = statsManager.getProcessesRankedByMemory()
        topProcesses = Array(processes.prefix(processDisplayLimit))
    }
}

private struct MemoryUsageDashboard: View {
    let breakdown: MemoryBreakdown
    let accentColor: Color
    
    private let freeColor = Color.gray.opacity(0.28)
    
    var body: some View {
        let totalsSection = VStack(alignment: .leading, spacing: 12) {
            DetailRow(color: accentColor.opacity(0.8), label: "Used", value: formattedBytes(breakdown.usedBytes))
            DetailRow(color: freeColor.opacity(0.9), label: "Free", value: formattedBytes(breakdown.freeBytes))
            DetailRow(color: nil, label: "Total", value: formattedBytes(breakdown.totalBytes))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        let breakdownSection = VStack(alignment: .leading, spacing: 8) {
            Text("Breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
            MemoryBreakdownRow(label: "App", value: breakdown.appBytes, total: breakdown.totalBytes, color: accentColor.opacity(0.85))
            MemoryBreakdownRow(label: "Cached", value: breakdown.cacheBytes, total: breakdown.totalBytes, color: accentColor.opacity(0.65))
            MemoryBreakdownRow(label: "Wired", value: breakdown.wiredBytes, total: breakdown.totalBytes, color: accentColor.opacity(0.45))
            MemoryBreakdownRow(label: "Compressed", value: breakdown.compressedBytes, total: breakdown.totalBytes, color: accentColor.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        return ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: 20) {
                usageRing
                totalsSection
                Divider().padding(.vertical, 4)
                breakdownSection
            }
            HStack(alignment: .top, spacing: 28) {
                usageRing
                totalsSection
                breakdownSection
            }
        }
    }
    
    private func formattedBytes(_ value: UInt64) -> String {
        StatsFormatting.bytes(value)
    }

    private var usageRing: some View {
        ZStack {
            Circle()
                .stroke(freeColor.opacity(0.35), lineWidth: 14)
                .frame(width: 128, height: 128)
            
            MemoryUsageRing(breakdown: breakdown, usedColor: accentColor, freeColor: freeColor)
                .frame(width: 128, height: 128)
            
            VStack(spacing: 4) {
                Text(StatsFormatting.percentage(breakdown.usedPercentage))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Used")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MemoryUsageRing: View {
    let breakdown: MemoryBreakdown
    let usedColor: Color
    let freeColor: Color
    
    var body: some View {
        ZStack {
            let usedFraction = CGFloat(min(max(breakdown.usedPercentage / 100, 0), 1))
            if usedFraction > 0 {
                RingArc(start: 0, end: usedFraction, color: usedColor, lineWidth: 14)
            }
            if usedFraction < 1 {
                RingArc(start: usedFraction, end: 1, color: freeColor.opacity(0.65), lineWidth: 14)
            }
        }
    }
}

private struct MemoryBreakdownRow: View {
    let label: String
    let value: UInt64
    let total: UInt64
    let color: Color
    
    var body: some View {
        let percent = total > 0 ? Double(value) / Double(total) * 100 : 0
        return DetailRow(color: color, label: label, value: "\(StatsFormatting.bytes(value)) · \(StatsFormatting.percentage(percent))")
    }
}

private struct MemoryHealthView: View {
    let breakdown: MemoryBreakdown
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MemoryPressureIndicator(pressure: breakdown.pressure)
            Divider().padding(.vertical, 4)
            SwapUsageView(swap: breakdown.swap, accentColor: accentColor)
        }
    }
}

private struct MemoryPressureIndicator: View {
    let pressure: MemoryPressure

    private var status: (title: String, color: Color, description: String) {
        switch pressure.level {
        case .normal:
            return ("Normal", Color.green, "System memory pressure is nominal.")
        case .warning:
            return ("Warning", Color.orange, "Memory pressure is elevated. Closing apps may help.")
        case .critical:
            return ("Critical", Color.red, "Memory pressure is critical; the system may purge aggressively.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pressure")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Capsule()
                    .fill(status.color.opacity(0.16))
                    .overlay(
                        HStack(spacing: 8) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 10, height: 10)
                            Text(status.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(status.color)
                        }
                        .padding(.horizontal, 12)
                    )
                    .frame(height: 28)
                Spacer()
            }

            Text(status.description)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

private struct SwapUsageView: View {
    let swap: MemorySwap
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Swap")
                .font(.caption)
                .foregroundColor(.secondary)

            if swap.totalBytes > 0 {
                DetailRow(color: accentColor.opacity(0.85), label: "Used", value: StatsFormatting.bytes(swap.usedBytes))
                DetailRow(color: accentColor.opacity(0.55), label: "Free", value: StatsFormatting.bytes(swap.freeBytes))
                DetailRow(color: nil, label: "Total", value: StatsFormatting.bytes(swap.totalBytes))
                SwapUsageBar(usedBytes: swap.usedBytes, totalBytes: swap.totalBytes, tint: accentColor)
                    .frame(height: 8)
            } else {
                Text("Swap is disabled on this system.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SwapUsageBar: View {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progress = totalBytes > 0 ? min(max(Double(usedBytes) / Double(totalBytes), 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint.opacity(0.8))
                    .frame(width: width * progress)
            }
        }
    }
}
