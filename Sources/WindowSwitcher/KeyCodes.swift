import AppKit
import Carbon.HIToolbox
import SwitcherCore

/// Key names for the config. Codes are physical positions (ANSI layout names), so "^" and "`" both mean the
/// key left of 1, whatever it prints on the current layout. Any other key can be given as its raw code;
/// `WindowSwitcher --keycodes` prints the code of every key pressed.
enum KeyCodes {
    private static let named: [String: Int] = [
        "tab": kVK_Tab, "space": kVK_Space, "return": kVK_Return, "escape": kVK_Escape, "delete": kVK_Delete,
        "`": kVK_ANSI_Grave, "^": kVK_ANSI_Grave, "grave": kVK_ANSI_Grave, "section": kVK_ISO_Section, "<": kVK_ISO_Section,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
        ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote, ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period,
        "/": kVK_ANSI_Slash, "\\": kVK_ANSI_Backslash,
        "left": kVK_LeftArrow, "right": kVK_RightArrow, "up": kVK_UpArrow, "down": kVK_DownArrow,
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
        "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
        "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
        "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    ]

    /// A name above, or a number: the raw code. Single digits are names, so code 1 to 9 can't be given raw.
    static func code(_ key: String) -> UInt32? {
        if let code = named[key.lowercased()] { return UInt32(code) }
        return UInt32(key)
    }

    static func carbonModifiers(_ names: [String]) -> UInt32 {
        names.reduce(0) { flags, name in
            switch Modifier.normalized(name) {
                case "command": return flags | UInt32(cmdKey)
                case "option": return flags | UInt32(optionKey)
                case "control": return flags | UInt32(controlKey)
                case "shift": return flags | UInt32(shiftKey)
                default: return flags
            }
        }
    }

    static func eventModifiers(_ names: [String]) -> NSEvent.ModifierFlags {
        names.reduce(into: NSEvent.ModifierFlags()) { flags, name in
            switch Modifier.normalized(name) {
                case "command": flags.insert(.command)
                case "option": flags.insert(.option)
                case "control": flags.insert(.control)
                case "shift": flags.insert(.shift)
                default: break
            }
        }
    }
}
