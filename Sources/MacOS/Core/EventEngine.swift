import CoreGraphics
import Foundation

final class EventEngine: @unchecked Sendable {

    // MARK: - Mouse

    static func click(at point: CGPoint, button: CGMouseButton = .left, clickCount: Int = 1) {
        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        for _ in 0..<clickCount {
            let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button)
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            up?.post(tap: .cghidEventTap)
        }
    }

    static func moveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    static func scroll(direction: ScrollDirection, amount: Int32 = 3) {
        let event: CGEvent?
        switch direction {
        case .up:
            event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)
        case .down:
            event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -amount, wheel2: 0, wheel3: 0)
        case .left:
            event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: amount, wheel3: 0)
        case .right:
            event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -amount, wheel3: 0)
        }
        event?.post(tap: .cghidEventTap)
    }

    enum ScrollDirection: String, CaseIterable, Sendable {
        case up, down, left, right
    }

    // MARK: - Keyboard

    static func typeText(_ text: String, delay: UInt32 = 5000) {
        for char in text {
            let utf16 = Array(String(char).utf16)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            event.post(tap: .cghidEventTap)
            let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)
            usleep(delay)
        }
    }

    static func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }

    static func hotkey(keys: [String]) throws {
        var modifiers: CGEventFlags = []
        var keyCode: CGKeyCode = 0
        var hasKey = false
        for key in keys {
            switch key.lowercased() {
            case "cmd", "command": modifiers.insert(.maskCommand)
            case "shift": modifiers.insert(.maskShift)
            case "alt", "option": modifiers.insert(.maskAlternate)
            case "ctrl", "control": modifiers.insert(.maskControl)
            case "fn": modifiers.insert(.maskSecondaryFn)
            default:
                guard let code = keyCodeMap[key.lowercased()] else { throw EventError.unknownKey(key) }
                keyCode = code
                hasKey = true
            }
        }
        guard hasKey else { throw EventError.noKeySpecified }
        pressKey(keyCode, modifiers: modifiers)
    }

    static let keyCodeMap: [String: CGKeyCode] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
        "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
        "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
        "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        "space": 49, "return": 36, "tab": 48, "escape": 53,
        "delete": 51, "backspace": 51,
        "arrow_up": 126, "arrow_down": 125, "arrow_left": 123, "arrow_right": 124,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]
}

enum EventError: Error, CustomStringConvertible {
    case unknownKey(String)
    case noKeySpecified
    var description: String {
        switch self {
        case .unknownKey(let key): return "未知按键: '\(key)'"
        case .noKeySpecified: return "快捷键组合中未指定主键"
        }
    }
}
