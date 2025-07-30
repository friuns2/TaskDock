//
//  TaskBarItemView.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 8/11/23.
//

import AXSwift
import SwiftUI

struct TaskBarItemView: View {
    let window: Window
    let groupedWindows: [Window]?
    let isActive: Bool
    let activeWindowId: CGWindowID
    let recentWindowIds: [CGWindowID]
    let onActivateWindow: ((CGWindowID) -> Void)?
    let isPinned: Bool
    let onTogglePin: ((String) -> Void)?
    
    init(window: Window, groupedWindows: [Window]? = nil, isActive: Bool = false, activeWindowId: CGWindowID = 0, recentWindowIds: [CGWindowID] = [], onActivateWindow: ((CGWindowID) -> Void)? = nil, isPinned: Bool = false, onTogglePin: ((String) -> Void)? = nil) {
        self.window = window
        self.groupedWindows = groupedWindows
        self.isActive = isActive
        self.activeWindowId = activeWindowId
        self.recentWindowIds = recentWindowIds
        self.onActivateWindow = onActivateWindow
        self.isPinned = isPinned
        self.onTogglePin = onTogglePin
    }
    
    private var recentWindows: [Window] {
        guard let grouped = groupedWindows, grouped.count > 1 else { return [] }
        
        // Sort by recent activity using the recentWindowIds order
        let sorted = grouped.sorted { lhs, rhs in
            let lhsIndex = recentWindowIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsIndex = recentWindowIds.firstIndex(of: rhs.id) ?? Int.max
            
            if lhsIndex == rhsIndex {
                return lhs.id < rhs.id // Fallback to ID order
            }
            return lhsIndex < rhsIndex
        }
        
        return Array(sorted.prefix(1))
    }
    
    var body: some View {
        if let grouped = groupedWindows, grouped.count > 1 {
            // Show last active window as separate clickable item
            HStack(spacing: 1) {
                ForEach(recentWindows, id: \.id) { win in
                    WindowItemView(
                        window: win,
                        icon: window.icon,
                        isActive: win.id == activeWindowId,
                        groupedWindows: grouped,
                        onActivateWindow: onActivateWindow
                    )
                }
            }
            .contextMenu {
                ForEach(grouped, id: \.id) { win in
                    Button(win.title ?? win.name) {
                        activateWindow(win)
                    }
                }
                Divider()
                Button(isPinned ? "Unpin App" : "Pin App") {
                    onTogglePin?(window.bundleId)
                }
                Divider()
                ForEach(grouped, id: \.id) { win in
                    Button("Close \(win.title ?? win.name)") {
                        closeWindow(win)
                    }
                }
            }
        } else {
            // Single window - show normally
            WindowItemView(
                window: window,
                icon: window.icon,
                isActive: isActive,
                groupedWindows: groupedWindows,
                onActivateWindow: onActivateWindow
            )
            .contextMenu {
                Button("Activate") {
                    activateWindow(window)
                }
                Divider()
                Button(isPinned ? "Unpin App" : "Pin App") {
                    onTogglePin?(window.bundleId)
                }
                Divider()
                Button("Close Window") {
                    closeWindow(window)
                }
            }
        }
    }
    
    private func activateWindow(_ window: Window) {
        let nsapp = NSRunningApplication(processIdentifier: window.pid)
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                print("cannot get CGWindow id (objc bridged call)")
            } else {
                return cgWindowId == window.id
            }
            return false
        })
        
        if let axwindow = axwindow {
            nsapp?.activate()
            try? axwindow.performAction(.raise)
            try? axwindow.setAttribute(.focused, value: kCFBooleanTrue)
            onActivateWindow?(window.id)
        } else {
            nsapp?.activate(options: .activateAllWindows)
        }
    }
    
    private func closeWindow(_ window: Window) {
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                print("cannot get CGWindow id (objc bridged call)")
            } else {
                return cgWindowId == window.id
            }
            return false
        })
        
        if let axwindow = axwindow {
            // Try to get the close button and press it
            do {
                if let closeButton: UIElement = try axwindow.attribute(.closeButton) {
                    try closeButton.performAction(.press)
                }
            } catch {
                print("Could not close window: \(error)")
            }
        }
    }
}

struct WindowItemView: View {
    let window: Window
    let icon: NSImage?
    let isActive: Bool
    let groupedWindows: [Window]?
    let onActivateWindow: ((CGWindowID) -> Void)?
    
    init(window: Window, icon: NSImage? = nil, isActive: Bool = false, groupedWindows: [Window]? = nil, onActivateWindow: ((CGWindowID) -> Void)? = nil) {
        self.window = window
        self.icon = icon
        self.isActive = isActive
        self.groupedWindows = groupedWindows
        self.onActivateWindow = onActivateWindow
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(truncatedTitle(window.title ?? window.name))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, -2)
        }
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 6))
        .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Color(NSColor.selectedControlColor) : Color(NSColor.controlColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            activateWindow(window)
        }
        .contextMenu {
            if let grouped = groupedWindows, grouped.count > 1 {
                ForEach(grouped, id: \.id) { win in
                    Button(win.title ?? win.name) {
                        activateWindow(win)
                    }
                }
                Divider()
                Button("Close Window") {
                    closeWindow(window)
                }
            } else {
                Button("Close Window") {
                    closeWindow(window)
                }
            }
        }
    }
    
    private func truncatedTitle(_ title: String) -> String {
        let maxLength = 60
        if title.count > maxLength {
            return String(title.prefix(maxLength - 3)) + "..."
        }
        return title
    }
    
    private func activateWindow(_ window: Window) {
        let nsapp = NSRunningApplication(processIdentifier: window.pid)
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                print("cannot get CGWindow id (objc bridged call)")
            } else {
                return cgWindowId == window.id
            }
            return false
        })
        
        if let axwindow = axwindow {
            nsapp?.activate()
            try? axwindow.performAction(.raise)
            try? axwindow.setAttribute(.focused, value: kCFBooleanTrue)
            onActivateWindow?(window.id)
        } else {
            nsapp?.activate(options: .activateAllWindows)
        }
    }
    
    private func closeWindow(_ window: Window) {
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                print("cannot get CGWindow id (objc bridged call)")
            }
            else {
                return cgWindowId == window.id
            }
            return false
        })
        
        if let axwindow = axwindow {
            // Try to get the close button and press it
            do {
                if let closeButton: UIElement = try axwindow.attribute(.closeButton) {
                    try closeButton.performAction(.press)
                }
            } catch {
                print("Could not close window: \(error)")
            }
        }
    }
}
