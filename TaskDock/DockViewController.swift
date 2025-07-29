//
//  DockViewController.swift
//  TaskDock
//
//  Created by Andrey Radchishin on 7/22/23.
//

import Cocoa

class DockViewController: NSViewController {
    public var space: Space {
        didSet {
            
        }
    }
    
    init(space: Space) {
        self.space = space
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init with coder not implemented")
    }
    
    override func loadView() {
        
    }
}
