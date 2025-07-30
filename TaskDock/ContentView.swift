//
//  ContentView.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 7/19/23.
//

import AXSwift
import Combine
import SwiftUI
import UniformTypeIdentifiers

/*
 TODO:
 - add "pinned" apps that show on one side always
 - app launcher menu
 - figure out how to catch window move events, etc.
 - "system tray"
 - ability to drag an app into the settings to add it (kind of like privacy settings work on mac)
 - automatically show common apps that a user might want to add there (discord, slack, telegram, etc.)
 */


struct ContentView: View {
    
    let displayId: CGDirectDisplayID
    
    let spacePub = PassthroughSubject<Space, Never>()
    
    @State var space: Space
    @State private var dragged: Window?
    @State var draggingWindows: [Window]?
    @State private var activeWindowId: CGWindowID = 0
    @State private var recentWindowIds: [CGWindowID] = [] // Track recently active windows
    @State private var pinnedBundleIds: Set<String> = [] // Track pinned applications
    @State private var pinnedWindowIds: Set<CGWindowID> = [] // Track pinned individual windows
    
    var onShowMenu: (() -> Void)?
    var onChangeOrder: ((_ displayId: CGDirectDisplayID, _ spaceId: CGSSpaceID, _ updated: [CGWindowID]) -> Void)?
    
    let sorter = SortHandler()
    
    private func handleWindowActivation(_ windowId: CGWindowID) {
        activeWindowId = windowId
        
        // Update recent windows history
        if let existingIndex = recentWindowIds.firstIndex(of: windowId) {
            recentWindowIds.remove(at: existingIndex)
        }
        recentWindowIds.insert(windowId, at: 0)
    }
    
    private func togglePin(for bundleId: String) {
        if pinnedBundleIds.contains(bundleId) {
            pinnedBundleIds.remove(bundleId)
        } else {
            pinnedBundleIds.insert(bundleId)
        }
        // Save pinned state to UserDefaults
        UserDefaults.standard.set(Array(pinnedBundleIds), forKey: "pinnedBundleIds")
    }
    
    private func toggleWindowPin(for windowId: CGWindowID) {
        if pinnedWindowIds.contains(windowId) {
            pinnedWindowIds.remove(windowId)
        } else {
            pinnedWindowIds.insert(windowId)
        }
        // Save pinned window state to UserDefaults
        UserDefaults.standard.set(Array(pinnedWindowIds), forKey: "pinnedWindowIds")
    }
    
    private func loadPinnedApps() {
        if let saved = UserDefaults.standard.array(forKey: "pinnedBundleIds") as? [String] {
            pinnedBundleIds = Set(saved)
        }
        if let savedWindows = UserDefaults.standard.array(forKey: "pinnedWindowIds") as? [CGWindowID] {
            pinnedWindowIds = Set(savedWindows)
        }
    }
    
    // Get pinned apps that don't have windows open
    private var pinnedAppsWithoutWindows: [String] {
        let activeBundleIds = Set(space.windows.map { $0.bundleId })
        return pinnedBundleIds.filter { !activeBundleIds.contains($0) }
    }
    
    // Get pinned windows that are currently available
    private var pinnedWindows: [Window] {
        return space.windows.filter { pinnedWindowIds.contains($0.id) }
    }
    
    var body: some View {
        
        HStack(spacing: 2) {
            
            Button(action: {
                onShowMenu?()
            }, label: {
                Image(systemName: "command").resizable().frame(width: 16, height: 16)
            }).buttonStyle(.borderless).padding(8)
            
            Button {
                let homeDir = FileManager.default.homeDirectoryForCurrentUser
                NSWorkspace.shared.open(homeDir)
            } label: {
                Image(systemName: "house").resizable().frame(width: 20, height: 20).symbolVariant(.fill)
            }.buttonStyle(.borderless).padding(8)

            HStack(spacing: 2) {
                // Show pinned apps without windows first
                ForEach(pinnedAppsWithoutWindows, id: \.self) { bundleId in
                    PinnedAppView(
                        bundleId: bundleId,
                        onTogglePin: togglePin
                    )
                }
                
                // Show pinned windows that don't have regular grouped representation
                ForEach(pinnedWindows, id: \.id) { window in
                    let hasGroupRepresentation = space.windows.filter { $0.bundleId == window.bundleId }.first?.id == window.id
                    if !hasGroupRepresentation {
                        PinnedWindowView(
                            window: window,
                            isActive: window.id == activeWindowId,
                            onActivateWindow: handleWindowActivation,
                            onToggleWindowPin: toggleWindowPin
                        )
                    }
                }
                
                // Show regular windows/apps
                ForEach(draggingWindows ?? space.windows, id: \.id) { window in
                    let groupedWindows = (draggingWindows ?? space.windows).filter { $0.bundleId == window.bundleId }
                    if groupedWindows.first?.id == window.id {  // Only show first window of each group
                        TaskBarItemView(
                            window: window, 
                            groupedWindows: groupedWindows, 
                            isActive: window.id == activeWindowId,
                            activeWindowId: activeWindowId,
                            recentWindowIds: recentWindowIds,
                            onActivateWindow: handleWindowActivation,
                            isPinned: pinnedBundleIds.contains(window.bundleId),
                            onTogglePin: togglePin,
                            pinnedWindowIds: pinnedWindowIds,
                            onToggleWindowPin: toggleWindowPin
                        )
                            .onDrag({
                                dragged = window
                                draggingWindows = [Window](space.windows)
                                return NSItemProvider(object: String(window.id) as NSString)
                            }, preview: {
                                Rectangle().fill(Color.clear)
                            })
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: ReorderDropDelegate(
                                    displayId: displayId,
                                    spaceId: space.id,
                                    item: window,
                                    onChangeOrder: onChangeOrder,
                                    data: $draggingWindows,
                                    dataa: $space.windows,
                                    dragged: $dragged)
                            )
                    }
                }
            }.padding(.horizontal, 8)
            
            Spacer(minLength: 16)
            
            Button(action: {
                CoreDockSendNotification("com.apple.expose.awake" as CFString)
            }, label: {
                Image(systemName: "macwindow.on.rectangle").resizable().frame(width: 18, height: 18)
            }).buttonStyle(.borderless).padding(8)

            Button(action: {
                CoreDockSendNotification("com.apple.showdesktop.awake" as CFString)
            }, label: {
                Image(systemName: "menubar.dock.rectangle").resizable().frame(width: 18, height: 18)
            }).buttonStyle(.borderless).padding(8)

        }.padding(8)
            .frame(maxWidth: .infinity, minHeight: 40)
            .onReceive(spacePub) { space in
                if dragged == nil {
                    self.space = space
                    draggingWindows = nil
                }
            }
            .onAppear {
                loadPinnedApps()
                // Start checking for active window
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    if let frontmostApp = NSWorkspace.shared.frontmostApplication,
                       let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                        for window in windowList {
                            if let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                               ownerPID == frontmostApp.processIdentifier,
                               let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                               let layer = window[kCGWindowLayer as String] as? Int,
                               layer == 0 {
                                
                                // Only update if window actually changed
                                if activeWindowId != windowID {
                                    handleWindowActivation(windowID)
                                }
                                break
                            }
                        }
                    }
                }
            }
    }
}

struct DockMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .offset(y: -10)
    }
}

struct ReorderDropDelegate: DropDelegate {
    let displayId: CGDirectDisplayID
    let spaceId: CGSSpaceID
    let item: Window
    let onChangeOrder: ((_ displayId: CGDirectDisplayID, _ spaceId: CGSSpaceID, _ updated: [CGWindowID]) -> Void)?
    
    @Binding var data: [Window]?
    @Binding var dataa: [Window]
    @Binding var dragged: Window?
    
    func dropEntered(info: DropInfo) {
        guard item != dragged,
              let current = dragged,
              let from = data?.firstIndex(of: current),
              let to = data?.firstIndex(of: item)
        else {
            return
        }
        
        if data?[to] != current {
            withAnimation {
                // Just move local array initially
                data?.move(fromOffsets: IndexSet(integer: from), toOffset: from < to ? (to + 1) : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        withAnimation {
            // Commit to the actual dataset
            onChangeOrder?(displayId, spaceId, data!.map { $0.id })
        }
        
        dragged = nil
        return true
    }
}

struct PinnedAppView: View {
    let bundleId: String
    let onTogglePin: ((String) -> Void)?
    
    @State private var appIcon: NSImage?
    @State private var appName: String = ""
    
    var body: some View {
        Button(action: {
            launchApp()
        }) {
            HStack(spacing: 4) {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app")
                        .frame(width: 20, height: 20)
                }
                
                if !appName.isEmpty {
                    Text(appName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 6))
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlColor).opacity(0.7)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button("Launch App") {
                launchApp()
            }
            Divider()
            Button("Unpin App") {
                onTogglePin?(bundleId)
            }
        }
        .onAppear {
            loadAppInfo()
        }
    }
    
    private func loadAppInfo() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        
        // Get app name
        if let bundle = Bundle(url: url) {
            appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                     bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                     url.deletingPathExtension().lastPathComponent
        }
        
        // Get app icon
        appIcon = NSWorkspace.shared.icon(forFile: url.path)
    }
    
    private func launchApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }
}

struct PinnedWindowView: View {
    let window: Window
    let isActive: Bool
    let onActivateWindow: ((CGWindowID) -> Void)?
    let onToggleWindowPin: ((CGWindowID) -> Void)?
    
    private func truncatedTitle(_ title: String) -> String {
        let maxLength = 60
        if title.count > maxLength {
            return String(title.prefix(maxLength - 3)) + "..."
        }
        return title
    }
    
    var body: some View {
        Button(action: {
            onActivateWindow?(window.id)
        }) {
            HStack(spacing: 4) {
                if let icon = window.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app")
                        .frame(width: 20, height: 20)
                }
                
                Text(truncatedTitle(window.title ?? window.name))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 6))
        .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Color(NSColor.selectedControlColor).opacity(0.8) : Color(NSColor.controlColor).opacity(0.5)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button("Activate Window") {
                onActivateWindow?(window.id)
            }
            Divider()
            Button("Unpin Window") {
                onToggleWindowPin?(window.id)
            }
        }
    }
}
