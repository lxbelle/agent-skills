// Real HID input fallback for pointer-level checks (mac-control skill).
// `--global` posts through the HID event tap: the cursor moves and the frontmost
// app receives true mouse/keyboard events (WebKit fires pointerdown). Without
// `--global` events are posted to the pid queue (CGEventPostToPid), which many
// web views ignore. Keyboard text is delivered as Unicode strings, independent
// of the keyboard layout. Build: swiftc -O -o <scratch>/hid-input hid-input.swift
import Foundation
import CoreGraphics

func usage() -> Never {
    FileHandle.standardError.write("usage: input <pid> click|dblclick <x> <y> | type <text>|- | key <keycode> [cmd|shift|alt|ctrl]...\n".data(using: .utf8)!)
    exit(2)
}
var args = CommandLine.arguments
// `--global` posts through the HID event tap (real system input: the cursor
// moves and the frontmost app receives it) instead of the target pid queue.
let global = args.count > 1 && args[1] == "--global"
if global { args.remove(at: 1) }
guard args.count >= 3, let pid = pid_t(args[1]) else { usage() }
let cmd = args[2]
func post(_ e: CGEvent?) {
    guard let e = e else { FileHandle.standardError.write("cannot create event\n".data(using: .utf8)!); exit(1) }
    if global { e.post(tap: .cghidEventTap) } else { e.postToPid(pid) }
}
switch cmd {
case "click", "dblclick":
    guard args.count >= 5, let x = Double(args[3]), let y = Double(args[4]) else { usage() }
    let p = CGPoint(x: x, y: y)
    post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left))
    usleep(30_000)
    for i in 1...(cmd == "dblclick" ? 2 : 1) {
        let d = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)
        d?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        post(d)
        usleep(40_000)
        let u = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)
        u?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        post(u)
        usleep(80_000)
    }
    print("\(cmd) posted to pid \(pid) at (\(x), \(y))")
case "type":
    guard args.count >= 4 else { usage() }
    var text = args[3...].joined(separator: " ")
    if text == "-" {
        text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
    var count = 0
    for scalar in text.unicodeScalars {
        var units = Array(String(scalar).utf16)
        let d = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        d?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        post(d)
        let u = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        u?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        post(u)
        usleep(12_000)
        count += 1
    }
    print("typed \(count) characters to pid \(pid)")
case "key":
    guard args.count >= 4, let code = UInt16(args[3]) else { usage() }
    var flags: CGEventFlags = []
    for m in args.dropFirst(4) {
        switch m {
        case "cmd": flags.insert(.maskCommand)
        case "shift": flags.insert(.maskShift)
        case "alt": flags.insert(.maskAlternate)
        case "ctrl": flags.insert(.maskControl)
        default: usage()
        }
    }
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true); d?.flags = flags; post(d)
    usleep(30_000)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false); u?.flags = flags; post(u)
    print("key \(code) posted to pid \(pid)")
default:
    usage()
}
