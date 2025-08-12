//
//  TaskBarItemView.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 8/11/23.
//

import AXSwift
import SwiftUI

private func reverseByLongDash(_ title: String) -> String {
    for dash in ["—", "–"] {
        if title.contains(dash) {
            let parts = title.components(separatedBy: dash)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count > 1 {
                return parts.reversed().joined(separator: " \(dash) ")
            }
        }
    }
    return title
}

struct TaskBarItemView: View {
    let window: Window
    let groupedWindows: [Window]?
    let isActive: Bool
    let activeWindowId: CGWindowID
    let recentWindowIds: [CGWindowID]
    let onActivateWindow: ((CGWindowID) -> Void)?
    let onTogglePin: ((CGWindowID) -> Void)?
    
    init(window: Window, groupedWindows: [Window]? = nil, isActive: Bool = false, activeWindowId: CGWindowID = 0, recentWindowIds: [CGWindowID] = [], onActivateWindow: ((CGWindowID) -> Void)? = nil, onTogglePin: ((CGWindowID) -> Void)? = nil) {
        self.window = window
        self.groupedWindows = groupedWindows
        self.isActive = isActive
        self.activeWindowId = activeWindowId
        self.recentWindowIds = recentWindowIds
        self.onActivateWindow = onActivateWindow
        self.onTogglePin = onTogglePin
    }
    
    private var recentWindows: [Window] {
        guard let grouped = groupedWindows, grouped.count > 1 else { return [] }
        
        // Get all pinned windows in this group
        let pinnedWindows = grouped.filter { $0.isPinned }
        
        // Get the most recent active window (only 1)
        let sorted = grouped.sorted { lhs, rhs in
            let lhsIndex = recentWindowIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsIndex = recentWindowIds.firstIndex(of: rhs.id) ?? Int.max
            
            if lhsIndex == rhsIndex {
                return lhs.id < rhs.id // Fallback to ID order
            }
            return lhsIndex < rhsIndex
        }
        
        let mostRecentActive = Array(sorted.prefix(1))
        
        // Combine pinned windows and most recent active window, avoiding duplicates
        var result: [Window] = []
        
        // Add pinned windows first
        result.append(contentsOf: pinnedWindows)
        
        // Add most recent active window if it's not already pinned
        for activeWindow in mostRecentActive {
            if !pinnedWindows.contains(where: { $0.id == activeWindow.id }) {
                result.append(activeWindow)
            }
        }
        
        return result
    }
    
    var body: some View {
        if let grouped = groupedWindows, grouped.count > 1 {
            // Show only 1 recent active window plus pinned windows as separate clickable items
            HStack(spacing: 1) {
                ForEach(recentWindows, id: \.id) { win in
                    WindowItemView(
                        window: win,
                        icon: window.icon,
                        isActive: win.id == activeWindowId,
                        groupedWindows: grouped,
                        activeWindowId: activeWindowId,
                        recentWindowIds: recentWindowIds,
                        onActivateWindow: onActivateWindow,
                        onTogglePin: onTogglePin
                    )
                }
            }
            .contextMenu {
                ForEach(grouped, id: \.id) { win in
                    Button(reverseByLongDash(win.title ?? win.name)) {
                        activateWindow(win)
                        // Also pin the window when activated from context menu
                        if !win.isPinned {
                            onTogglePin?(win.id)
                        }
                    }
                }
                Divider()
                ForEach(grouped, id: \.id) { win in
                    Button("Close \(reverseByLongDash(win.title ?? win.name))") {
                        closeWindow(win)
                    }
                }
                Divider()
                Button(window.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar") {
                    onTogglePin?(window.id)
                }
            } preview: {
                // Auto-pin when context menu appears
                if !window.isPinned {
                    DispatchQueue.main.async {
                        onTogglePin?(window.id)
                    }
                }
                return Rectangle().fill(Color.clear)
            }
        } else {
            WindowItemView(
                window: window,
                icon: window.icon,
                isActive: isActive,
                groupedWindows: groupedWindows,
                activeWindowId: activeWindowId,
                recentWindowIds: recentWindowIds,
                onActivateWindow: onActivateWindow,
                onTogglePin: onTogglePin
            )
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
            if let closeButton: UIElement = try? axwindow.attribute(.closeButton) {
                try? closeButton.performAction(.press)
            }
        }
    }
    
    private func hideWindow(_ window: Window) {
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
            try? axwindow.setAttribute(.minimized, value: true)
        }
    }
    
    private func minimizeWindow(_ window: Window) {
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                return false
            }
            return cgWindowId == window.id
        })
        
        if let axwindow = axwindow {
            try? axwindow.setAttribute(.minimized, value: true)
        }
    }
}

struct WindowItemView: View {
    let window: Window
    let icon: NSImage?
    let isActive: Bool
    let groupedWindows: [Window]?
    let activeWindowId: CGWindowID
    let recentWindowIds: [CGWindowID]
    let onActivateWindow: ((CGWindowID) -> Void)?
    let onTogglePin: ((CGWindowID) -> Void)?
    
    init(window: Window, icon: NSImage? = nil, isActive: Bool = false, groupedWindows: [Window]? = nil, activeWindowId: CGWindowID = 0, recentWindowIds: [CGWindowID] = [], onActivateWindow: ((CGWindowID) -> Void)? = nil, onTogglePin: ((CGWindowID) -> Void)? = nil) {
        self.window = window
        self.icon = icon
        self.isActive = isActive
        self.groupedWindows = groupedWindows
        self.activeWindowId = activeWindowId
        self.recentWindowIds = recentWindowIds
        self.onActivateWindow = onActivateWindow
        self.onTogglePin = onTogglePin
    }
    
    private func activateWindowById(_ windowId: CGWindowID) {
        // Get all windows on screen to find the target window
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            for windowInfo in windowList {
                if let windowNumber = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                   windowNumber == windowId,
                   let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t {
                    
                    let nsapp = NSRunningApplication(processIdentifier: ownerPID)
                    let app = Application.init(forProcessID: ownerPID)
                    let windows = try? app?.windows()
                    
                    let axwindow = windows?.first(where: { w in
                        var cgWindowId = CGWindowID()
                        if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                            return false
                        }
                        return cgWindowId == windowId
                    })
                    
                    if let axwindow = axwindow {
                        nsapp?.activate()
                        try? axwindow.performAction(.raise)
                        try? axwindow.setAttribute(.focused, value: kCFBooleanTrue)
                        onActivateWindow?(windowId)
                    } else {
                        nsapp?.activate(options: .activateAllWindows)
                    }
                    return
                }
            }
        }
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(truncatedTitle(reverseByLongDash(window.title ?? window.name)))
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, -2)
        }
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 6))
        .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Color(NSColor.selectedControlColor) : Color(NSColor.controlColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            // If the clicked window is already active, activate the previous window
            if window.id == activeWindowId && recentWindowIds.count > 1 {
                // Find the previous window (second in the recent list)
                let previousWindowId = recentWindowIds[1]
                
                // Find the window object for the previous window ID
                if let grouped = groupedWindows,
                   let previousWindow = grouped.first(where: { $0.id == previousWindowId }) {
                    activateWindow(previousWindow)
                } else {
                    // If previous window not in current group, use the general activation method
                    activateWindowById(previousWindowId)
                }
            } else {
                // Normal activation for non-active windows
                activateWindow(window)
            }
        }
        .contextMenu {
            if let grouped = groupedWindows, grouped.count > 1 {
                ForEach(grouped, id: \.id) { win in
                    Button(reverseByLongDash(win.title ?? win.name)) {
                        activateWindow(win)
                        // Also pin the window when activated from context menu
                        if !win.isPinned {
                            onTogglePin?(win.id)
                        }
                    }
                }
                Divider()
                Button("Close Window") {
                    closeWindow(window)
                }
                Button("Minimize Window") {
                    minimizeWindow(window)
                }
                Divider()
                Button(window.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar") {
                    onTogglePin?(window.id)
                }
            } else {
                Button("Close Window") {
                    closeWindow(window)
                }
                Button("Minimize Window") {
                    minimizeWindow(window)
                }
                Divider()
                Button(window.isPinned ? "Unpin from Taskbar" : "Pin to Taskbar") {
                    onTogglePin?(window.id)
                }
            }
        } preview: {
            // Auto-pin when context menu appears
            if !window.isPinned {
                DispatchQueue.main.async {
                    onTogglePin?(window.id)
                }
            }
            return Rectangle().fill(Color.clear)
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
    
    private func hideWindow(_ window: Window) {
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
            try? axwindow.setAttribute(.minimized, value: true)
        }
    }
    
    private func minimizeWindow(_ window: Window) {
        let app = Application.init(forProcessID: window.pid)
        let windows = try! app?.windows()
        
        let axwindow = windows?.first(where: { w in
            var cgWindowId = CGWindowID()
            if (_AXUIElementGetWindow(w.element, &cgWindowId) != .success) {
                return false
            }
            return cgWindowId == window.id
        })
        
        if let axwindow = axwindow {
            try? axwindow.setAttribute(.minimized, value: true)
        }
    }
}
