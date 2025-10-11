//
//  IdleAnimationsSettingsSection.swift
//  DynamicIsland
//
//  Created by AI Assistant on 11/10/2025.
//  Settings section for custom idle animations
//

import SwiftUI
import Defaults
import LottieUI
import UniformTypeIdentifiers

struct IdleAnimationsSettingsSection: View {
    @Default(.customIdleAnimations) var customIdleAnimations
    @Default(.selectedIdleAnimation) var selectedIdleAnimation
    @Default(.showNotHumanFace) var showNotHumanFace
    
    @State private var showingFilePicker = false
    @State private var showingURLSheet = false
    @State private var urlInput = ""
    @State private var nameInput = ""
    @State private var selectedForDeletion: CustomIdleAnimation?
    @State private var showingDeleteAlert = false
    @State private var importError: String?
    @State private var showingError = false
    
    // Animation editor state
    @State private var showingEditor = false
    @State private var editorSourceURL: URL?
    @State private var editorIsRemote = false
    @State private var editedAnimation: CustomIdleAnimation?
    @State private var editingExistingAnimation: CustomIdleAnimation?
    
    var body: some View {
        Section {
            if showNotHumanFace {
                // Horizontal scrollable grid of animations
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(customIdleAnimations) { animation in
                            AnimationPreviewCard(
                                animation: animation,
                                isSelected: selectedIdleAnimation?.id == animation.id,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedIdleAnimation = animation
                                    }
                                },
                                onDelete: animation.isBuiltIn ? nil : {
                                    selectedForDeletion = animation
                                    showingDeleteAlert = true
                                },
                                onEdit: animation.isBuiltIn ? nil : {
                                    editingExistingAnimation = animation
                                    if case .lottieFile(let url) = animation.source {
                                        editorSourceURL = url
                                        editorIsRemote = false
                                        showingEditor = true
                                    } else if case .lottieURL(let url) = animation.source {
                                        editorSourceURL = url
                                        editorIsRemote = true
                                        showingEditor = true
                                    }
                                }
                            )
                        }
                        
                        // Add animation button
                        AddAnimationCard {
                            showingFilePicker = true
                        } onAddURL: {
                            urlInput = ""
                            nameInput = ""
                            showingURLSheet = true
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
                .frame(height: 140)
            } else {
                Text("Enable \"Show cool face animation while inactivity\" to customize animations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        } header: {
            HStack {
                Text("Idle Animation Style")
                Spacer()
                if showNotHumanFace {
                    Text("\(customIdleAnimations.count) animations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if showNotHumanFace {
                Text("Choose animation to display when Dynamic Island is idle. Tap to select, hold to delete custom animations.")
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingURLSheet) {
            URLImportSheet(
                urlInput: $urlInput,
                nameInput: $nameInput,
                onImport: { handleURLImport() },
                onCancel: { showingURLSheet = false }
            )
        }
        .sheet(isPresented: $showingEditor) {
            if let url = editorSourceURL {
                AnimationEditorView(
                    sourceURL: url,
                    isRemoteURL: editorIsRemote,
                    animation: $editedAnimation,
                    existingAnimation: editingExistingAnimation
                )
                .frame(minWidth: 800, minHeight: 600)
                .onChange(of: editedAnimation) { oldValue, newValue in
                    if let animation = newValue {
                        // Animation was successfully imported/edited via editor
                        if let existingAnim = editingExistingAnimation {
                            // Editing existing animation - update it
                            if var animations = customIdleAnimations as? [CustomIdleAnimation],
                               let index = animations.firstIndex(where: { $0.id == existingAnim.id }) {
                                animations[index] = animation
                                customIdleAnimations = animations
                                // Update selection if this was the selected animation
                                if selectedIdleAnimation?.id == existingAnim.id {
                                    selectedIdleAnimation = animation
                                }
                            }
                        } else {
                            // New import - just select it
                            withAnimation {
                                selectedIdleAnimation = animation
                            }
                        }
                        showingEditor = false
                        // Reset editor state
                        editorSourceURL = nil
                        editedAnimation = nil
                        editingExistingAnimation = nil
                    }
                }
            }
        }
        .alert("Delete Animation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let animation = selectedForDeletion {
                    IdleAnimationManager.shared.deleteAnimation(animation)
                }
            }
        } message: {
            if let animation = selectedForDeletion {
                Text("Are you sure you want to delete \"\(animation.name)\"?")
            }
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(importError ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Import Handlers
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Show editor instead of directly importing
            editorSourceURL = url
            editorIsRemote = false
            editedAnimation = nil
            showingEditor = true
            
        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }
    
    private func handleURLImport() {
        guard let url = URL(string: urlInput), !nameInput.isEmpty else {
            importError = "Please provide both a valid URL and name"
            showingError = true
            return
        }
        
        // Show editor instead of directly importing
        editorSourceURL = url
        editorIsRemote = true
        editedAnimation = nil
        showingURLSheet = false
        showingEditor = true
    }
}

// MARK: - Animation Preview Card
struct AnimationPreviewCard: View {
    let animation: CustomIdleAnimation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Preview area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2.5
                            )
                    )
                
                // Animation preview
                AnimationPreview(animation: animation)
                    .frame(width: 60, height: 40)
                
                // Delete button (only for custom animations)
                if let onDelete = onDelete, isHovering {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                onDelete()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .red)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 100, height: 80)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            
            // Name and badge
            VStack(spacing: 4) {
                Text(animation.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
                
                if isSelected {
                    Text("Selected")
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                } else if animation.isBuiltIn {
                    Text("Built-in")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            if let onEdit = onEdit {
                Button("Edit Animation") {
                    onEdit()
                }
                Divider()
            }
            if let onDelete = onDelete {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}

// MARK: - Animation Preview
struct AnimationPreview: View {
    let animation: CustomIdleAnimation
    
    var body: some View {
        switch animation.source {
        case .lottieFile(let url):
            LottieView(state: LUStateData(
                type: .loadedFrom(url),
                speed: animation.speed,
                loopMode: .loop
            ))
            .frame(width: 60, height: 40)
            
        case .lottieURL(let url):
            LottieView(state: LUStateData(
                type: .loadedFrom(url),
                speed: animation.speed,
                loopMode: .loop
            ))
            .frame(width: 60, height: 40)
            
        case .builtInFace:
            MinimalFaceFeatures(height: 40, width: 60)
                .scaleEffect(2.0)  // Scale up the face for preview
        }
    }
}

// MARK: - Add Animation Card
struct AddAnimationCard: View {
    let onAddFile: () -> Void
    let onAddURL: () -> Void
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                showingMenu.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Add")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 80)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showingMenu = false
                        onAddFile()
                    } label: {
                        Label("Import File...", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    
                    Divider()
                    
                    Button {
                        showingMenu = false
                        onAddURL()
                    } label: {
                        Label("Add from URL...", systemImage: "link.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                .frame(width: 180)
            }
            
            Text("Add New")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 100)
        }
    }
}

// MARK: - URL Import Sheet
struct URLImportSheet: View {
    @Binding var urlInput: String
    @Binding var nameInput: String
    let onImport: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Animation from URL")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Lottie JSON URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://example.com/animation.json", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Animation Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("My Animation", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    onImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlInput.isEmpty || nameInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: - Preview
#Preview {
    Form {
        IdleAnimationsSettingsSection()
    }
    .frame(width: 600, height: 400)
}
