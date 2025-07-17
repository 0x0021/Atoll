//
//  ClipboardManager.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 17/07/25.
//

import AppKit
import SwiftUI
import Combine
import Foundation
import UniformTypeIdentifiers

// Clipboard item data structure
struct ClipboardItem: Identifiable, Codable {
    let id = UUID()
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    
    // Store different types of data - avoid large binary data in UserDefaults
    let stringData: String?
    let imageFileName: String? // Store filename instead of data
    let fileURLs: [String]?
    let rtfData: Data? // RTF is typically small, so we can keep this
    
    init(stringData: String, type: ClipboardItemType) {
        self.stringData = stringData
        self.imageFileName = nil
        self.fileURLs = nil
        self.rtfData = nil
        self.type = type
        self.timestamp = Date()
        self.preview = ClipboardItem.generatePreview(stringData: stringData, type: type)
    }
    
    init(imageData: Data) {
        self.stringData = nil
        self.fileURLs = nil
        self.rtfData = nil
        self.type = .image
        self.timestamp = Date()
        
        // Save image data to temporary file instead of storing in UserDefaults
        let fileName = "clipboard_image_\(UUID().uuidString).png"
        let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            self.imageFileName = fileName
            self.preview = "Image (\(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)))"
        } catch {
            print("Failed to save image data: \(error)")
            self.imageFileName = nil
            self.preview = "Image (failed to save)"
        }
    }
    
    init(fileURLs: [String]) {
        self.stringData = nil
        self.imageFileName = nil
        self.fileURLs = fileURLs
        self.rtfData = nil
        self.type = .file
        self.timestamp = Date()
        
        if fileURLs.count == 1, let url = URL(string: fileURLs.first!) {
            self.preview = url.lastPathComponent
        } else {
            self.preview = "\(fileURLs.count) files"
        }
    }
    
    init(rtfData: Data, plainText: String) {
        // RTF data is typically small, so we can keep it in UserDefaults
        self.stringData = plainText
        self.imageFileName = nil
        self.fileURLs = nil
        self.rtfData = rtfData.count > 100000 ? nil : rtfData // Skip very large RTF files
        self.type = .rtf
        self.timestamp = Date()
        self.preview = String(plainText.prefix(50))
    }
    
    // Helper to get image data from file
    func getImageData() -> Data? {
        guard let fileName = imageFileName else { return nil }
        let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
    
    static func generatePreview(stringData: String, type: ClipboardItemType) -> String {
        switch type {
        case .text:
            return String(stringData.prefix(50))
        case .url:
            if let url = URL(string: stringData) {
                return url.lastPathComponent.isEmpty ? url.host ?? stringData : url.lastPathComponent
            }
            return String(stringData.prefix(50))
        case .file:
            if let url = URL(string: stringData) {
                return url.lastPathComponent
            }
            return "File"
        case .image:
            return "Image"
        case .rtf:
            return String(stringData.prefix(50))
        case .unknown:
            return String(stringData.prefix(50))
        }
    }
}

enum ClipboardItemType: String, CaseIterable, Codable {
    case text = "text"
    case url = "url"
    case file = "file"
    case image = "image"
    case rtf = "rtf"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        case .rtf: return "doc.richtext"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        case .file: return "File"
        case .image: return "Image"
        case .rtf: return "Rich Text"
        case .unknown: return "Unknown"
        }
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var isMonitoring: Bool = false
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxHistoryItems = 3
    
    // Directory for storing clipboard data files
    static let clipboardDataDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let clipboardDir = documentsPath.appendingPathComponent("ClipboardData")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        
        return clipboardDir
    }()
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadHistoryFromDefaults()
        cleanupOldFiles()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url:
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        case .image:
            if let imageData = item.getImageData() {
                pasteboard.setData(imageData, forType: .png)
            }
        case .file:
            if let fileURLs = item.fileURLs {
                let urls = fileURLs.compactMap { URL(string: $0) }
                pasteboard.writeObjects(urls as [NSPasteboardWriting])
            }
        case .rtf:
            if let rtfData = item.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Also set plain text as fallback
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        case .unknown:
            if let stringData = item.stringData {
                pasteboard.setString(stringData, forType: .string)
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        // Clean up associated files
        if let fileName = item.imageFileName {
            let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        clipboardHistory.removeAll { $0.id == item.id }
        saveHistoryToDefaults()
    }
    
    func clearHistory() {
        // Clean up all associated files
        for item in clipboardHistory {
            if let fileName = item.imageFileName {
                let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        
        clipboardHistory.removeAll()
        saveHistoryToDefaults()
    }
    
    // MARK: - Private Methods
    
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        guard let clipboardItem = getCurrentClipboardItem() else { return }
        
        // Don't add duplicate items
        if !clipboardHistory.contains(where: { isSameContent($0, clipboardItem) }) {
            addToHistory(clipboardItem)
        }
    }
    
    private func getCurrentClipboardItem() -> ClipboardItem? {
        let pasteboard = NSPasteboard.general
        
        // Step 1: Check what types are available
        let hasFileURLs = pasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
        let hasImageData = pasteboard.data(forType: .png) != nil || 
                          pasteboard.data(forType: .tiff) != nil || 
                          pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) != nil
        let hasString = pasteboard.string(forType: .string) != nil
        
        // Step 2: Smart detection based on context
        
        // Priority 1: If there are file URLs AND the files are actual image files, treat as image files (from Finder)
        if hasFileURLs {
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                let realFileURLs = fileURLs.filter { url in
                    return url.isFileURL && 
                           !url.path.contains("/.file/id=") && 
                           !url.path.contains("/tmp/") && 
                           !url.path.hasPrefix("/private/var/") && 
                           !url.path.contains("/ClipboardViewer") && 
                           FileManager.default.fileExists(atPath: url.path)
                }
                
                if !realFileURLs.isEmpty {
                    // Check if these are image files - if so, try to load the actual image data
                    let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
                    let imageFiles = realFileURLs.filter { url in
                        imageExtensions.contains(url.pathExtension.lowercased())
                    }
                    
                    // If we have image files from Finder, load the actual image data
                    if !imageFiles.isEmpty, let firstImageURL = imageFiles.first {
                        if let imageData = try? Data(contentsOf: firstImageURL) {
                            return ClipboardItem(imageData: imageData)
                        }
                    }
                    
                    // Otherwise, treat as file(s)
                    let urlStrings = realFileURLs.map { $0.absoluteString }
                    return ClipboardItem(fileURLs: urlStrings)
                }
            }
        }
        
        // Priority 2: If there's ONLY image data without file URLs (screenshots, direct image paste)
        if hasImageData && !hasFileURLs {
            if let imageData = pasteboard.data(forType: .png) {
                return ClipboardItem(imageData: imageData)
            } else if let imageData = pasteboard.data(forType: .tiff) {
                return ClipboardItem(imageData: imageData)
            } else if let imageData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                return ClipboardItem(imageData: imageData)
            }
        }
        
        // Priority 3: Plain text (including copied text)
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Determine if it's a URL
            if string.hasPrefix("http://") || string.hasPrefix("https://") {
                return ClipboardItem(stringData: string, type: .url)
            }
            return ClipboardItem(stringData: string, type: .text)
        }
        
        // Priority 4: RTF
        if let rtfData = pasteboard.data(forType: .rtf),
           let rtfString = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string, !rtfString.isEmpty {
            return ClipboardItem(rtfData: rtfData, plainText: rtfString)
        }
        
        // Priority 5: If we have image data WITH file URLs (document thumbnails), 
        // this is likely a document with a preview - ignore the thumbnail and treat as unknown
        if hasImageData && hasFileURLs {
            // This is likely a document with a thumbnail preview - we don't want the thumbnail
            return nil
        }
        
        // Priority 6: URL strings
        if let url = pasteboard.string(forType: .URL) {
            return ClipboardItem(stringData: url, type: .url)
        }
        
        return nil
    }
    
    private func addToHistory(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove any existing items with the same data
            let itemsToRemove = self.clipboardHistory.filter { existingItem in
                return self.isSameContent(existingItem, item)
            }
            
            // Clean up files for items being removed
            for oldItem in itemsToRemove {
                if let fileName = oldItem.imageFileName {
                    let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
            self.clipboardHistory.removeAll { existingItem in
                return self.isSameContent(existingItem, item)
            }
            
            // Add to beginning of array
            self.clipboardHistory.insert(item, at: 0)
            
            // Keep only the most recent items and clean up old files
            let itemsToDelete = Array(self.clipboardHistory.dropFirst(self.maxHistoryItems))
            for oldItem in itemsToDelete {
                if let fileName = oldItem.imageFileName {
                    let fileURL = ClipboardManager.clipboardDataDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
            if self.clipboardHistory.count > self.maxHistoryItems {
                self.clipboardHistory = Array(self.clipboardHistory.prefix(self.maxHistoryItems))
            }
            
            self.saveHistoryToDefaults()
        }
    }
    
    // Helper to compare clipboard items for duplicates
    private func isSameContent(_ item1: ClipboardItem, _ item2: ClipboardItem) -> Bool {
        if item1.type != item2.type { return false }
        
        switch item1.type {
        case .text, .url, .unknown:
            return item1.stringData == item2.stringData
        case .image:
            // For images, compare the actual data if both are available
            let data1 = item1.getImageData()
            let data2 = item2.getImageData()
            return data1 == data2
        case .file:
            return item1.fileURLs == item2.fileURLs
        case .rtf:
            return item1.stringData == item2.stringData && item1.rtfData == item2.rtfData
        }
    }
    
    // Clean up old image files that are no longer referenced
    private func cleanupOldFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: ClipboardManager.clipboardDataDirectory, includingPropertiesForKeys: nil) else { return }
        
        let referencedFiles = Set(clipboardHistory.compactMap { $0.imageFileName })
        
        for file in files {
            let fileName = file.lastPathComponent
            if !referencedFiles.contains(fileName) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveHistoryToDefaults() {
        if let encoded = try? JSONEncoder().encode(clipboardHistory) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardHistory")
        }
    }
    
    private func loadHistoryFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: "ClipboardHistory"),
           let history = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardHistory = history
        }
    }
}
