import AppKit
import Foundation

struct Window { let remaining: Int; let reset: Date? }

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var timer: Timer?
    var busy = false
    var lastSuccess: Date?
    var five: Window?
    var week: Window?
    var error: String?
    let cli = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "Codex …"
        item.menu = menu
        render()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func color(_ n: Int) -> NSColor { n <= 10 ? .systemRed : (n <= 30 ? .systemOrange : .systemGreen) }
    func render() {
        if let b = item.button {
            if let a = five, let w = week {
                let s = NSMutableAttributedString(string: "5h ", attributes: [.foregroundColor: NSColor.labelColor])
                s.append(NSAttributedString(string: "\(a.remaining)%", attributes: [.foregroundColor: color(a.remaining)]))
                s.append(NSAttributedString(string: "  W ", attributes: [.foregroundColor: NSColor.labelColor]))
                s.append(NSAttributedString(string: "\(w.remaining)%", attributes: [.foregroundColor: color(w.remaining)]))
                b.attributedTitle = s
            } else { b.title = error == nil ? "Codex …" : "Codex !" }
            b.toolTip = error ?? "Codex usage remaining"
        }
        menu.removeAllItems()
        func add(_ title: String) { let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""); i.isEnabled = false; menu.addItem(i) }
        func line(_ title: String, _ window: Window?) {
            guard let window else { add("\(title): unavailable"); return }
            var s = "\(title): \(window.remaining)% remaining"
            if let d = window.reset { s += " · resets " + DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .short) }
            add(s)
        }
        line("5-hour", five); line("Weekly", week)
        if let lastSuccess { add("Updated " + DateFormatter.localizedString(from: lastSuccess, dateStyle: .none, timeStyle: .short)) }
        if let error { add("Update failed: \(error)") }
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: busy ? "Refreshing…" : "Refresh now", action: #selector(refreshAction), keyEquivalent: "r"); refresh.target = self; refresh.isEnabled = !busy; menu.addItem(refresh)
        let quit = NSMenuItem(title: "Quit Codex Usage", action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    @objc func refreshAction() { refresh() }
    @objc func quitAction() { NSApplication.shared.terminate(nil) }
    func refresh() {
        guard !busy else { return }; busy = true; render()
        DispatchQueue.global(qos: .utility).async {
            let result = self.fetch()
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let windows): self.five = windows.0; self.week = windows.1; self.error = nil; self.lastSuccess = Date()
                case .failure(let e): self.error = e.localizedDescription
                }
                self.render()
            }
        }
    }
    enum FetchError: LocalizedError { case message(String); var errorDescription: String? { if case .message(let s) = self { return s }; return nil } }
    func fetch() -> Result<(Window?, Window?), Error> {
        do {
            guard FileManager.default.isExecutableFile(atPath: cli) else { throw FetchError.message("Codex CLI not found in ChatGPT.app") }
            let process = Process(); process.executableURL = URL(fileURLWithPath: cli); process.arguments = ["app-server"]
            let input = Pipe(), output = Pipe(), errors = Pipe()
            process.standardInput = input; process.standardOutput = output; process.standardError = errors
            try process.run()
            defer { if process.isRunning { process.terminate() }; try? input.fileHandleForWriting.close() }
            let requests: [[String: Any]] = [
                ["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "codex_usage_menu", "version": "1.0"]]],
                ["method": "initialized", "params": [:]],
                ["id": 2, "method": "account/rateLimits/read", "params": [:]]
            ]
            for request in requests { var data = try JSONSerialization.data(withJSONObject: request); data.append(10); try input.fileHandleForWriting.write(contentsOf: data) }
            let deadline = Date().addingTimeInterval(20)
            let fd = output.fileHandleForReading.fileDescriptor
            var buffer = Data()
            while Date() < deadline {
                var pollfdValue = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                let n = poll(&pollfdValue, 1, 500)
                if n <= 0 { if !process.isRunning { break }; continue }
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }; buffer.append(chunk)
                while let index = buffer.firstIndex(of: 10) {
                    let line = Data(buffer[..<index]); buffer.removeSubrange(...index)
                    guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any], (obj["id"] as? Int) == 2 else { continue }
                    if let e = obj["error"] as? [String: Any] { throw FetchError.message(e["message"] as? String ?? "server error") }
                    guard let result = obj["result"] as? [String: Any] else { throw FetchError.message("invalid server response") }
                    let byId = result["rateLimitsByLimitId"] as? [String: Any]
                    guard let limits = (byId?["codex"] as? [String: Any]) ?? (result["rateLimits"] as? [String: Any]) else { throw FetchError.message("limits unavailable; check sign-in") }
                    var five: Window?, week: Window?
                    for key in ["primary", "secondary"] {
                        guard let w = limits[key] as? [String: Any], let used = w["usedPercent"] as? Double, let minutes = w["windowDurationMins"] as? Int else { continue }
                        let value = Window(remaining: max(0, min(100, Int((100 - used).rounded()))), reset: (w["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) })
                        if minutes == 300 { five = value }; if minutes == 10080 { week = value }
                    }
                    if five == nil && week == nil { throw FetchError.message("no 5-hour or weekly window returned") }
                    return .success((five, week))
                }
            }
            throw FetchError.message("Codex server unavailable or timed out")
        } catch { return .failure(error) }
    }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
