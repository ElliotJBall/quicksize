//
//  AppDelegate.swift
//  quicksize
//
//  Created by Elliot Ball on 21/12/2020.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let BUILT_IN_SCREEN_NAME = "Built-in Retina Display"
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    var screenNamesToDisplayId: [String: CGDirectDisplayID] = [:]
    var screenNameToDisplayMode: [String: [String:CGDisplayMode]] = [:]
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
            
            constructMenu()
        } else {
            fatalError("Failed to create status bar button image - Cannot instantiate the application.")
        }
        
        observeScreenChanges()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func constructMenu() {
        screenNamesToDisplayId = [:]
        screenNameToDisplayMode = [:]
        
        
        NSScreen.screens.forEach {
            screenNamesToDisplayId[$0.localizedName] = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        }
        
        
        let menu = NSMenu()
        
        for screenName in screenNamesToDisplayId.keys {
            screenNameToDisplayMode[screenName] = [:]
            
            let displayNameMenuItem = NSMenuItem(title: screenName, action: nil, keyEquivalent: "")
            displayNameMenuItem.isEnabled = false
            
            let displayModes = CGDisplayCopyAllDisplayModes(screenNamesToDisplayId[screenName]!, nil)
            
            for i in 0..<CFArrayGetCount(displayModes) {
                let displayMode = unsafeBitCast(CFArrayGetValueAtIndex(displayModes, i), to: CGDisplayMode.self)
                let roundedRefreshRate = round(displayMode.refreshRate)
                let resolutionDisplayValue = "\(displayMode.width) X \(displayMode.height) X \(roundedRefreshRate)"
                
                // Some resolutions appear just below 60 HZ (E.g. 59.123456). Only apply this conditional to external screens
                // as the built-in mac screen has a refresh rate of 0 for all resolutions
                if ( roundedRefreshRate < 59 && screenName != BUILT_IN_SCREEN_NAME ) {
                    continue
                }
                
                // The underlying CGDisplayCopyAllDisplayModes returns the same resolutions but different display modes
                // Lazily safeguarding against adding the same resolution by just using the first one we've seen
                if ((screenNameToDisplayMode[screenName]?[resolutionDisplayValue]) != nil) {
                    continue
                }
                
                screenNameToDisplayMode[screenName]?[resolutionDisplayValue] = displayMode
            }
        }
        
        // After we've retrieved the list of resolutions per screen, sort them by their width and height, descending order
        for screenName in screenNamesToDisplayId.keys {
            let optSorted = screenNameToDisplayMode[screenName]?.sorted{ (first, second) -> Bool in
                return (first.value.width > second.value.width)
                    && (first.value.height > second.value.height)
            }
            
            if let sorted = optSorted {
                let displayNameMenuItem = NSMenuItem(title: screenName, action: nil, keyEquivalent: "")
                displayNameMenuItem.isEnabled = false
                menu.addItem(displayNameMenuItem)
                
                for entry in sorted {
                    let resolutionDisplayValue = entry.key
                    let displayMode = entry.value
                    
                    menu.addItem(BetterNsMenuItem(screenName: screenName, resolutionDisplayValue: resolutionDisplayValue, width: displayMode.width, height: displayMode.height, title: resolutionDisplayValue, action: #selector(AppDelegate.changeResolution(menuItem:)), keyEquivalent: ""))
                }
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        menu.addItem(NSMenuItem(title: "Quit quicksize", action: #selector(quitClicked), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    
    func observeScreenChanges() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(constructMenu),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil
        )
    }
    
    @objc func changeResolution(menuItem: BetterNsMenuItem) {
        let optDisplayId = screenNamesToDisplayId[menuItem.screenName!]
        let optDisplayMode = screenNameToDisplayMode[menuItem.screenName!]?[menuItem.resolutionDisplayValue!]
        
        if let displayId = optDisplayId, let displayMode = optDisplayMode {
            CGDisplaySetDisplayMode( displayId, displayMode, nil)
        } else {
            print("Couldn't change resolution as display id or mode as missing!")
        }
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(self)
    }
    
    class BetterNsMenuItem : NSMenuItem {
        var screenName: String?
        var resolutionDisplayValue: String?
        var width: Int?
        var height: Int?
        
        convenience init(screenName: String, resolutionDisplayValue: String, width: Int, height: Int,
                         title: String, action selector: Selector?, keyEquivalent charCode: String) {
            self.init(title: title, action: selector, keyEquivalent: charCode)
            
            self.screenName = screenName
            self.resolutionDisplayValue = resolutionDisplayValue
            self.width = width
            self.height = height
        }
    }
}

