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
    
    private func handleTogglePin(_ windowId: CGWindowID) {
        PinnedWindowsManager.shared.togglePin(windowId: windowId)
        
        // Update isPinned for the specific window
        if let window = space.windows.first(where: { $0.id == windowId }) {
            window.isPinned = PinnedWindowsManager.shared.isPinned(windowId: windowId)
        }
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
                            onTogglePin: handleTogglePin
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
