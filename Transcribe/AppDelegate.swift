import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var aboutWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var statusBarItem: NSStatusItem?
    /// Shared settings manager, set by TranscribeApp after launch
    var settingsManager: SettingsManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clean up any leftover files from previous session (in case of force quit)
        cleanupTemporaryFiles(isStartup: true)
        
        setupStatusBar()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupTemporaryFiles(isStartup: false)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribe")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: localized("open_transcribe"), action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: localized("new_recording"), action: #selector(startNewRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: localized("quick_transcribe"), action: #selector(quickTranscribe), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: localized("preferences") + "...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: localized("about_transcribe_menu"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: localized("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
    }
    
    private func cleanupTemporaryFiles(isStartup: Bool = false) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Transcribe")
        
        do {
            try FileManager.default.removeItem(at: tempDir)
        } catch {
            // Cleanup failed or directory doesn't exist
        }
    }
    
    @objc func statusBarButtonClicked() {
        if let menu = statusBarItem?.menu {
            statusBarItem?.button?.performClick(nil)
        }
    }
    
    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func startNewRecording() {
        NotificationCenter.default.post(name: .startNewRecording, object: nil)
        openMainWindow()
    }
    
    @objc func quickTranscribe() {
        // Show quick transcribe floating window
        let quickTranscribeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        quickTranscribeWindow.title = localized("quick_transcribe")
        quickTranscribeWindow.center()
        quickTranscribeWindow.contentView = NSHostingView(rootView: QuickTranscribeView())
        quickTranscribeWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = localized("preferences")
            preferencesWindow?.center()
            
            guard let manager = settingsManager else {
                return
            }
            
            preferencesWindow?.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(manager)
            )
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func showAbout() {
        showAboutWindow()
    }

    func showAboutWindow() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = localized("about_transcribe")
            window.center()
            window.contentView = NSHostingView(rootView: AboutView())
            window.isReleasedWhenClosed = false
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                self?.aboutWindow = nil
            }
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let startNewRecording = Notification.Name("startNewRecording")
    static let quickTranscribe = Notification.Name("quickTranscribe")
}