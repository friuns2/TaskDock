//
//  AppDelegate.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 7/19/23.
//

import AXSwift
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var dockWindows: [CGDirectDisplayID: (window: DockWindow, view: ContentView)] = [:]
    private var menuWindow: MenuWindow!

    private var stateHandler: StateHandler!
    private var changeHandler: ChangeHandler!
    private var orderHandler: OrderHandler!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Check for accessibility permissions and exit if we don't have it
        guard AXSwift.checkIsProcessTrusted(prompt: true) else {
            print("Not trusted as an AX process; please authorize and re-launch")
            NSApp.terminate(self)
            return
        }
                
        menuWindow = MenuWindow()
        menuWindow.contentView = NSHostingView(rootView: MenuView())
        
        stateHandler = StateHandler()
        changeHandler = ChangeHandler()
        orderHandler = OrderHandler()
        
        changeHandler.onRecreate = recreate
        changeHandler.onRefresh = refresh
        
        changeHandler.register()
        
        recreate()
    }
    
    private func recreate() {
        let state = stateHandler.recreate()
        orderHandler.update(state: state)

        // Remove existing
        dockWindows.forEach { displayId, dock in
            dock.window.close()
        }

        let mainDisplayId = CGMainDisplayID()

        // Create dock only for the main display with all windows from all displays
        dockWindows = Dictionary(uniqueKeysWithValues: state.displays.filter { $0.key == mainDisplayId }.map { displayId, display in

            // Create dock using display frame for positioning
            let dock = DockWindow(screenFrame: display.frame)

            // Create a combined space with all windows from all displays and all spaces
            let combinedSpace = Space(id: 0) // Use 0 as a special ID for the combined space
            state.displays.forEach { _, display in
                display.spaces.forEach { _, space in
                    combinedSpace.windows.append(contentsOf: space.windows)
                }
            }

            var view = ContentView(displayId: displayId, space: combinedSpace)
            view.onShowMenu = { self.openMenu(on: display.frame) }
            view.onChangeOrder = { displayId, spaceId, updated in
                // For combined space, we need special handling - this might be complex
                // For now, we'll just refresh the combined space
                let newState = self.stateHandler.refresh()
                self.orderHandler.update(state: newState)

                let newCombinedSpace = Space(id: 0)
                newState.displays.forEach { _, display in
                    display.spaces.forEach { _, space in
                        newCombinedSpace.windows.append(contentsOf: space.windows)
                    }
                }
                view.spacePub.send(newCombinedSpace)
            }
            dock.contentView = NSHostingView(rootView: view)

            // Bring to front
            dock.orderFront(nil)

            return (displayId, (window: dock, view: view))
        })
    }
    
    private func refresh() {
        let state = stateHandler.refresh()
        orderHandler.update(state: state)

        // Update the main display's dock with all windows from all displays
        dockWindows.forEach { displayId, dock in
            let display = state.displays[displayId]!

            // Create a combined space with all windows from all displays and all spaces
            let combinedSpace = Space(id: 0) // Use 0 as a special ID for the combined space
            state.displays.forEach { _, display in
                display.spaces.forEach { _, space in
                    combinedSpace.windows.append(contentsOf: space.windows)
                }
            }

            // Trigger a resize on all windows if needed (using main display bounds)
            combinedSpace.windows.forEach { window in
                window.fixOverlap(screenY: display.bounds.origin.y, screenHeight: display.frame.height, dockHeight: dock.window.frame.height)
            }

            dock.view.spacePub.send(combinedSpace)
        }
    }
    
    private func openMenu(on screenFrame: NSRect) {
        NSApp.activate(ignoringOtherApps: true)
        menuWindow.moveToScreen(withFrame: screenFrame)
        menuWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func onWorkspaceChanged(_ notification: Notification) {
        print("change")
        
//        windows.forEach { (id, window) in
//            
//
//            
//            window.1!.publisher.send(currentSpace)
//        }
        
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Generate initial set of docks
    }
    
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

