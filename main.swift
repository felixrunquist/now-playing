import AppKit

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let maxLen = 40
let helper = Bundle.main.path(forResource: "helper", ofType: "dylib")!
let artPath = NSTemporaryDirectory() + "nowplaying-art"

// Run the helper inside /usr/bin/perl, which Apple allows to call MediaRemote.
func fetch() -> (text: String, art: NSImage?)? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    p.arguments = ["-e", "use DynaLoader; DynaLoader::dl_load_file(\"\(helper)\",0); sleep 3"]
    p.environment = ["NP_ART": artPath]
    let out = Pipe()
    p.standardOutput = out
    try? FileManager.default.removeItem(atPath: artPath)
    guard (try? p.run()) != nil else { return nil }
    // helper exits the process itself once it has printed
    let data = out.fileHandleForReading.readDataToEndOfFile()
    let lines = String(decoding: data, as: UTF8.self).components(separatedBy: "\n")
    guard lines.count >= 2, !lines[0].isEmpty else { return nil }
    var text = lines[1].isEmpty ? lines[0] : "\(lines[1]) – \(lines[0])"
    if text.count > maxLen { text = String(text.prefix(maxLen - 1)) + "…" }
    let art = lines.contains("art") ? NSImage(contentsOfFile: artPath) : nil
    art?.size = NSSize(width: 18, height: 18)
    return (text, art)
}

func update() {
    DispatchQueue.global().async {
        let r = fetch()
        DispatchQueue.main.async {
            item.button?.title = r.map { " " + $0.text } ?? ""
            item.button?.image = r?.art
            item.button?.imagePosition = .imageLeft
        }
    }
}

let menu = NSMenu()
menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
item.menu = menu
NSApplication.shared.setActivationPolicy(.accessory)
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in update() }
update()
NSApplication.shared.run()
