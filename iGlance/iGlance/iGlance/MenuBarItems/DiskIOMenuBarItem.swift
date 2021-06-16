//
//  DiskIOMenuBarItem.swift
//  iGlance
//
//  Created by nay on 2021/6/8.
//  Copyright © 2021 iGlance. All rights reserved.
//

import Foundation
import CocoaLumberjack

class DiskIOMenuBarItem: MenuBarItem {
    private let DIFFER: Int64 = 1024 * 256
    let MAX_VAL: Double = 100
    let readColor = NSColor.colorFrom(hex: "#2ea3e5")
    let writeColor = NSColor.colorFrom(hex: "#dc4942")
    let blackColor = NSColor.colorFrom(hex: "#FFFFFF")

    override init() {
        super.init()
    }

    func update() {
        self.statusItem.isVisible = AppDelegate.userSettings.settings.disk.showDiskIO
        if !self.statusItem.isVisible {
            return
        }

        updateMenuBarIcon()
    }

    /**
     * Updates the icon of the menu bar item. This function is called during every update interval.
     */
    func updateMenuBarIcon() {
        // get the button of the menu bar item
        guard let button = self.statusItem.button else {
            DDLogError("Could not retrieve the button of the 'NetworkMenuBarItem'")
            return
        }

        let (read, write) = DiskInfo.getActivityStat()
        var currentColor: NSColor = blackColor
        var currentValue: Double = 0
        if max(read, write) > self.DIFFER {
            if read > write {
                currentColor = self.readColor
                currentValue = self.MAX_VAL
            } else {
                currentColor = self.writeColor
                currentValue = self.MAX_VAL
            }
        }
        DDLogInfo("rstat wstat not in \(currentColor.toHex())")
        let barGraph = BarGraph(maxValue: self.MAX_VAL)
        button.image = barGraph.getImage(currentValue: currentValue, graphColor: currentColor, drawBorder: true, gradientColor: nil)
    }
}
