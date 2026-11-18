import AppKit

let maxLen = 40
let helper = Bundle.main.path(forResource: "helper", ofType: "dylib")!
let artPath = NSTemporaryDirectory() + "nowplaying-art"

// One status item: art + title on the left, play/pause and skip icons on the right.
// macOS may split separate items around the notch, so everything lives in one item.
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let btnW: CGFloat = 22
// Icons are only drawn. The status button receives every click (see Actions.clicked).
class IconView: NSButton { override func hitTest(_ p: NSPoint) -> NSView? { nil } }
class LabelView: NSTextField { override func hitTest(_ p: NSPoint) -> NSView? { nil } }
class ArtView: NSImageView { override func hitTest(_ p: NSPoint) -> NSView? { nil } }
let playButton = IconView()
let skipButton = IconView()
let label = LabelView(labelWithString: "")
let artView = ArtView()
let pad: CGFloat = 8

// MediaRemote command ids
let cmdPlay = 0, cmdPause = 1, cmdNext = 4, cmdPrev = 5
var isPlaying = false

// Run the helper inside /usr/bin/perl, which Apple allows to call MediaRemote.
func runHelper(_ env: [String: String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    p.arguments = ["-e", "use DynaLoader; DynaLoader::dl_load_file(\"\(helper)\",0); sleep 3"]
    p.environment = env
    let out = Pipe()
    p.standardOutput = out
    guard (try? p.run()) != nil else { return "" }
    // helper exits the process itself once it is done
    return String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
}

func fetch() -> (text: String, playing: Bool, art: NSImage?)? {
    try? FileManager.default.removeItem(atPath: artPath)
    let lines = runHelper(["NP_ART": artPath]).components(separatedBy: "\n")
    guard lines.count >= 3, !lines[0].isEmpty else { return nil }
    var text = lines[1].isEmpty ? lines[0] : "\(lines[1]) – \(lines[0])"
    if text.count > maxLen { text = String(text.prefix(maxLen - 1)) + "…" }
    let art = lines.contains("art") ? NSImage(contentsOfFile: artPath) : nil
    art?.size = NSSize(width: 18, height: 18)
    return (text, lines[2] == "1", art)
}

func symbol(_ name: String) -> NSImage? {
    let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    img?.isTemplate = true
    return img
}

// Menu item title with an inline symbol (item.image does not render here)
func titled(_ sym: String, _ text: String) -> NSAttributedString {
    let a = NSTextAttachment()
    a.image = symbol(sym)
    let out = NSMutableAttributedString(attachment: a)
    out.append(NSAttributedString(string: "  " + text))
    return out
}

func update() {
    DispatchQueue.global().async {
        let r = fetch()
        DispatchQueue.main.async {
            isPlaying = r?.playing == true
            playButton.image = symbol(isPlaying ? "pause.fill" : "play.fill")
            let show = r != nil
            for v in [playButton, skipButton, label] as [NSView] { v.isHidden = !show }
            artView.isHidden = r?.art == nil
            artView.image = r?.art
            guard let r else { item.length = NSStatusItem.variableLength; return }
            label.stringValue = r.text
            label.sizeToFit()
            // layout: pad, art, gap, label, gap, play, skip, pad
            var x = pad
            if r.art != nil { artView.frame = NSRect(x: x, y: 2, width: 18, height: 18); x += 22 }
            label.frame.origin = NSPoint(x: x, y: (22 - label.frame.height) / 2)
            x += ceil(label.frame.width) + 6
            playButton.frame.origin.x = x
            skipButton.frame.origin.x = x + btnW
            item.length = x + 2 * btnW + pad
        }
    }
}

func send(_ cmd: Int) {
    DispatchQueue.global().async {
        _ = runHelper(["NP_CMD": String(cmd)])
        update()
    }
}

class Actions: NSObject {
    @objc func toggle() { send(isPlaying ? cmdPause : cmdPlay) }
    @objc func next() { send(cmdNext) }
    @objc func prev() { send(cmdPrev) }
    // Route by cursor position: right-most icon skips, next one toggles, the rest opens the menu.
    @objc func clicked() {
        let b = item.button!
        let x = b.convert(b.window!.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil).x
        if !playButton.isHidden && x >= skipButton.frame.minX { next() }
        else if !playButton.isHidden && x >= playButton.frame.minX { toggle() }
        else { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: b.bounds.height + 5), in: b) }
    }
}
let actions = Actions()

for (b, name) in [(playButton, "play.fill"), (skipButton, "forward.fill")] {
    b.image = symbol(name)
    b.isBordered = false
    b.imagePosition = .imageOnly
    b.frame = NSRect(x: 0, y: 0, width: btnW, height: 22)
    b.isHidden = true
    item.button!.addSubview(b)
}
label.font = .menuBarFont(ofSize: 0)
label.isHidden = true
artView.imageScaling = .scaleProportionallyUpOrDown
artView.wantsLayer = true
artView.layer?.cornerRadius = 3
artView.layer?.masksToBounds = true
item.button!.addSubview(artView)
item.button!.addSubview(label)
item.button?.target = actions
item.button?.action = #selector(Actions.clicked)

let menu = NSMenu()
let prevMenuItem = menu.addItem(withTitle: "Previous", action: #selector(Actions.prev), keyEquivalent: "")
prevMenuItem.target = actions
prevMenuItem.attributedTitle = titled("backward.fill", "Previous")
menu.addItem(.separator())
let quit = menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
quit.attributedTitle = titled("xmark", "Quit")

NSApplication.shared.setActivationPolicy(.accessory)
Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in update() }
update()
NSApplication.shared.run()
