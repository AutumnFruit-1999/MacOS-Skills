import ApplicationServices
import Foundation

struct Permissions {
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options: CFDictionary = ["AXTrustedCheckOptionPrompt": prompt] as NSDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func ensureAccessibility() throws {
        guard checkAccessibility(prompt: true) else {
            throw PermissionError.accessibilityNotGranted
        }
    }
}

enum PermissionError: Error, CustomStringConvertible {
    case accessibilityNotGranted
    case screenRecordingNotGranted

    var description: String {
        switch self {
        case .accessibilityNotGranted:
            return "需要辅助功能权限。请前往：系统设置 > 隐私与安全性 > 辅助功能"
        case .screenRecordingNotGranted:
            return "需要屏幕录制权限。请前往：系统设置 > 隐私与安全性 > 屏幕录制"
        }
    }
}
