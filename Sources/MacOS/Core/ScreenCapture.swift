import ScreenCaptureKit
import AppKit

@available(macOS 14.0, *)
final class ScreenCapture: @unchecked Sendable {

    private static func ensureCGSConnection() {
        let _ = NSApplication.shared
    }

    static func captureScreen(saveTo path: String) async throws {
        ensureCGSConnection()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try saveImage(image, to: path)
    }

    static func captureWindow(pid: pid_t, saveTo path: String) async throws {
        ensureCGSConnection()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }
        guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(display: display, including: [window])
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.shouldBeOpaque = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try saveImage(image, to: path)
    }

    private static func saveImage(_ image: CGImage, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CaptureError.saveFailed
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CaptureError.saveFailed }
    }
}

enum CaptureError: Error, CustomStringConvertible {
    case noDisplay, windowNotFound, saveFailed
    var description: String {
        switch self {
        case .noDisplay: return "未找到显示器"
        case .windowNotFound: return "目标窗口未找到"
        case .saveFailed: return "截图保存失败"
        }
    }
}
