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
    
    init(window: Window, groupedWindows: [Window]? = nil, isActive: Bool = false) {
        self.window = window
        self.groupedWindows = groupedWindows
        self.isActive = isActive
    }
    
    var body: some View {
        HStack {
            if let icon = window.icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            if let grouped = groupedWindows, grouped.count > 1 {
                Text("\(window.name) (\(grouped.count))")
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.leading, -2)
            } else {
                Text("\(window.title ?? window.name)")
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.leading, -2)
            }
        }.padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 6))
            .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Color(NSColor.selectedControlColor) : Color(NSColor.controlColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contextMenu {
                if let grouped = groupedWindows, grouped.count > 1 {
                    ForEach(grouped, id: \.id) { win in
                        Button(win.title ?? win.name) {
                            activateWindow(win)
                        }
                    }
                }
            }
        .onTapGesture {
            activateWindow(window)
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
        } else {
            nsapp?.activate(options: .activateAllWindows)
        }
    }
}
