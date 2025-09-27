//
//  ScreenAssistantPanel.swift
//  DynamicIsland
//
//  Created by Hariharan Mudaliar

import AppKit
import SwiftUI
import Defaults
import UniformTypeIdentifiers

// MARK: - Backward Compatibility Wrapper
class ScreenAssistantPanel: NSPanel {
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        // This is now a compatibility wrapper
        // The actual functionality is handled by the new ChatPanels
        setupWindow()
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            close()
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func setupWindow() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]
        
        // Apply screen capture hiding setting
        updateScreenCaptureVisibility()
        setupScreenCaptureObserver()
        
        // Set minimal size since this is just a wrapper
        setContentSize(CGSize(width: 1, height: 1))
        setFrameOrigin(CGPoint(x: -1000, y: -1000)) // Move offscreen
    }
    
    // Trigger the new panel system
    override func makeKeyAndOrderFront(_ sender: Any?) {
        ScreenAssistantManager.shared.showPanels()
        // Don't actually show this wrapper panel
    }
    
    override func close() {
        ScreenAssistantManager.shared.closePanels()
        super.close()
    }
    
    private func setupScreenCaptureObserver() {
        // Observe changes to hidePanelsFromScreenCapture setting
        Defaults.observe(.hidePanelsFromScreenCapture) { [weak self] change in
            DispatchQueue.main.async {
                self?.updateScreenCaptureVisibility()
            }
        }
    }
    
    private func updateScreenCaptureVisibility() {
        let shouldHide = Defaults[.hidePanelsFromScreenCapture]
        
        if shouldHide {
            // Hide from screen capture and recording
            self.sharingType = .none
            print("🙈 ScreenAssistantPanel: Hidden from screen capture and recordings")
        } else {
            // Allow normal screen capture
            self.sharingType = .readOnly
            print("👁️ ScreenAssistantPanel: Visible in screen capture and recordings")
        }
    }
}

// Keep the old panel view for any existing references, but make it redirect
struct ScreenAssistantPanelView: View {
    let onClose: () -> Void
    
    var body: some View {
        VStack {
            Text("Screen Assistant")
                .onAppear {
                    // Redirect to new panel system
                    ScreenAssistantManager.shared.showPanels()
                    onClose()
                }
        }
        .frame(width: 1, height: 1)
    }
}

// MARK: - Shared Components (moved to ChatPanels.swift for the new implementation)
// These are kept here for backward compatibility only

struct MarkdownText: View {
    let content: String
    
    var body: some View {
        // Simple markdown parsing for now
        Text(parseMarkdown(content))
            .font(.system(size: 14))
            .textSelection(.enabled)
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple bold parsing (**text**)
        let boldPattern = #"\*\*(.*?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let boldText = String(text[range]).replacingOccurrences(of: "**", with: "")
                    if let attrRange = Range(match.range, in: attributedString) {
                        var boldAttributedText = AttributedString(boldText)
                        boldAttributedText.font = .system(size: 14, weight: .bold)
                        attributedString.replaceSubrange(attrRange, with: boldAttributedText)
                    }
                }
            }
        }
        
        return attributedString
    }
}

struct AttachedFileChip: View {
    let file: ScreenAssistantFile
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: file.type.iconName)
                .foregroundColor(.blue)
                .font(.system(size: 12))
            
            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 10))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
        .frame(maxWidth: 120)
    }
}

struct AddFilesButton: View {
    @ObservedObject var screenAssistantManager = ScreenAssistantManager.shared
    
    var body: some View {
        Button(action: selectFiles) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))
        }
        .buttonStyle(PlainButtonStyle())
        .help("Add files")
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.data, .image, .movie, .audio, .text, .pdf]
        
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    screenAssistantManager.addFiles(panel.urls)
                }
            }
        } else {
            if panel.runModal() == .OK {
                screenAssistantManager.addFiles(panel.urls)
            }
        }
    }
}

struct RecordingButton: View {
    @ObservedObject var screenAssistantManager = ScreenAssistantManager.shared
    
    var body: some View {
        Button(action: {
            screenAssistantManager.toggleRecording()
        }) {
            ZStack {
                Circle()
                    .fill(screenAssistantManager.isRecording ? Color.red : Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: screenAssistantManager.isRecording ? "stop.fill" : "mic.fill")
                    .foregroundColor(screenAssistantManager.isRecording ? .white : .blue)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(screenAssistantManager.isRecording ? "Stop recording" : "Start recording")
        .scaleEffect(screenAssistantManager.isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: screenAssistantManager.isRecording)
    }
}

struct ApiKeyAlertView: View {
    @State private var apiKey = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Enter your Gemini API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    // Dialog will close automatically
                }
                
                Button("Save") {
                    Defaults[.geminiApiKey] = apiKey
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(width: 300)
    }
}

#Preview {
    ScreenAssistantPanelView {
        print("Close panel")
    }
}