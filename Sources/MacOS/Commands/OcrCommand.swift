import ArgumentParser
import AppKit

struct OcrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ocr", abstract: "OCR 识别屏幕文字（基于 macOS Vision 框架）")

    @Option(name: .long, help: "目标应用名（默认前台应用）")
    var app: String?

    @Option(name: .long, help: "区域 'x,y,w,h'（单独使用=屏幕绝对坐标；配合 --app=窗口相对坐标）")
    var region: String?

    @Option(name: .long, help: "按文字内容过滤（包含匹配）")
    var query: String?

    @Flag(name: .long, help: "人类可读格式输出")
    var human = false

    func run() async throws {
        let elements: [OCRTextElement]

        if let regionStr = region, app != nil {
            elements = try await ocrAppRegion(regionStr)
        } else if let regionStr = region {
            elements = try await ocrRegion(regionStr)
        } else {
            elements = try await ocrApp()
        }

        let filtered = filterResults(elements)
        outputResults(filtered)
    }

    private func ocrApp() async throws -> [OCRTextElement] {
        let engine = AccessibilityEngine()
        guard let pid = (app.flatMap { engine.findApp(name: $0) } ?? engine.frontmostApp()) else {
            Output.error("应用未找到: \(app ?? "frontmost")")
            throw ExitCode.failure
        }

        if #available(macOS 14.0, *) {
            let (image, frame) = try await ScreenCapture.captureWindowImage(pid: pid)
            return try OCREngine.recognize(image: image, screenRect: frame)
        } else {
            Output.error("OCR 需要 macOS 14.0+")
            throw ExitCode.failure
        }
    }

    private func ocrAppRegion(_ regionStr: String) async throws -> [OCRTextElement] {
        let parts = parseRegion(regionStr)
        guard let parts = parts else {
            Output.error("区域格式错误，使用 'x,y,w,h'")
            throw ExitCode.failure
        }

        let engine = AccessibilityEngine()
        guard let pid = (app.flatMap { engine.findApp(name: $0) } ?? engine.frontmostApp()) else {
            Output.error("应用未找到: \(app ?? "frontmost")")
            throw ExitCode.failure
        }

        if #available(macOS 14.0, *) {
            let (image, windowFrame) = try await ScreenCapture.captureWindowImage(pid: pid)

            let imgW = CGFloat(image.width)
            let imgH = CGFloat(image.height)
            let scaleX = imgW / windowFrame.width
            let scaleY = imgH / windowFrame.height

            let cropX = Int(parts.x * scaleX)
            let cropY = Int(parts.y * scaleY)
            let cropW = Int(parts.w * scaleX)
            let cropH = Int(parts.h * scaleY)

            let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
                .intersection(CGRect(x: 0, y: 0, width: Int(imgW), height: Int(imgH)))

            guard !cropRect.isEmpty, let croppedImage = image.cropping(to: cropRect) else {
                Output.error("裁剪区域超出窗口范围")
                throw ExitCode.failure
            }

            let screenRect = CGRect(
                x: windowFrame.origin.x + parts.x,
                y: windowFrame.origin.y + parts.y,
                width: parts.w,
                height: parts.h
            )
            return try OCREngine.recognize(image: croppedImage, screenRect: screenRect)
        } else {
            Output.error("OCR 需要 macOS 14.0+")
            throw ExitCode.failure
        }
    }

    private func ocrRegion(_ regionStr: String) async throws -> [OCRTextElement] {
        guard let parts = parseRegion(regionStr) else {
            Output.error("区域格式错误，使用 'x,y,w,h'")
            throw ExitCode.failure
        }
        let rect = CGRect(x: parts.x, y: parts.y, width: parts.w, height: parts.h)
        let image = try await OCREngine.captureRegion(rect)
        return try OCREngine.recognize(image: image, screenRect: rect)
    }

    private func parseRegion(_ regionStr: String) -> (x: Double, y: Double, w: Double, h: Double)? {
        let parts = regionStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return (x: parts[0], y: parts[1], w: parts[2], h: parts[3])
    }

    private func filterResults(_ elements: [OCRTextElement]) -> [OCRTextElement] {
        guard let q = query, !q.isEmpty else { return elements }
        return elements.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private func outputResults(_ elements: [OCRTextElement]) {
        let appName = app ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
        if human {
            print("应用: \(appName) | 识别: \(elements.count) 个文字区域")
            for el in elements {
                let conf = String(format: "%.2f", el.confidence)
                print("  [\(conf)] \"\(el.text)\" (\(Int(el.frame.x)),\(Int(el.frame.y)) \(Int(el.frame.w))×\(Int(el.frame.h)))")
            }
        } else {
            Output.printCodable(OcrResult(app: appName, count: elements.count, elements: elements))
        }
    }
}

struct OcrResult: Codable {
    let app: String
    let count: Int
    let elements: [OCRTextElement]
}
