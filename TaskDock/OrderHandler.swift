//
//  OrderHandler.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 8/10/23.
//

class OrderHandler {

    private var _stored: [CGDirectDisplayID: [CGSSpaceID: ([CGWindowID], [CGWindowID: Int])]] = [:]
    private var _combinedSpaceOrder: [CGWindowID] = [] // Store order for combined space (spaceId = 0)
    
    public func update(state: StateModel) {
        state.displays.forEach { displayId, display in
            var storedDisplay = _stored[displayId, orInit: [:]]
            display.spaces.forEach { spaceId, space in
                let spaceData = storedDisplay[spaceId, orInit: ([], [:])]
                var (arr, dict) = spaceData

                // Add any windows that aren't accounted for
                space.windows.forEach { window in
                    if !dict.keys.contains(window.id) {
                        dict[window.id] = arr.count
                        arr.append(window.id)
                    }
                }

                storedDisplay[spaceId] = (arr, dict)
                _stored[displayId] = storedDisplay

                // Sort the StateModel windows based on our stored order
                space.windows.sort { lhs, rhs in
                    guard let lhsIndex = dict[lhs.id] else { return false }
                    guard let rhsIndex = dict[rhs.id] else { return true }
                    return lhsIndex < rhsIndex
                }


            }
        }
    }

    public func updateCombinedSpace(windows: inout [Window]) {
        // Initialize combined space order if empty
        if _combinedSpaceOrder.isEmpty {
            _combinedSpaceOrder = windows.map { $0.id }
        }

        // Add any new windows that aren't in our order
        let currentWindowIds = Set(windows.map { $0.id })
        let storedWindowIds = Set(_combinedSpaceOrder)

        // Add new windows to the end
        let newWindows = currentWindowIds.subtracting(storedWindowIds)
        _combinedSpaceOrder.append(contentsOf: newWindows)

        // Remove windows that no longer exist
        _combinedSpaceOrder = _combinedSpaceOrder.filter { currentWindowIds.contains($0) }

        // Sort windows based on combined space order
        windows.sort { lhs, rhs in
            guard let lhsIndex = _combinedSpaceOrder.firstIndex(of: lhs.id) else { return false }
            guard let rhsIndex = _combinedSpaceOrder.firstIndex(of: rhs.id) else { return true }
            return lhsIndex < rhsIndex
        }
    }
    
    public func move(displayId: CGDirectDisplayID, spaceId: CGSSpaceID, updated arr: [CGWindowID]) {
        guard var display = _stored[displayId] else { return }

        var dict = [CGWindowID: Int]()
        arr.enumerated().forEach { (index, window) in
            dict[window]  = index
        }

        display[spaceId] = (arr, dict)
        _stored[displayId] = display
    }

    public func moveCombinedSpace(updated arr: [CGWindowID]) {
        _combinedSpaceOrder = arr
    }
}
