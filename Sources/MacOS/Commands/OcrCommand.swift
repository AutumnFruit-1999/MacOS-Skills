import ArgumentParser
import AppKit

struct OcrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ocr", abstract: "OCR 识别屏幕文字（基于 macOS Vision 框架）")

    @Option(name: .long, help: "目标应用名（默认前台应用）")
    var app: String?

    @Option(name: .long, help: "屏幕区域 'x,y,w,h'（与 --app 互斥）")
    var region: String?

    @Option(name: .long, help: "按文字内容过滤（包含匹配）")
    var query: String?

    @Flag(name: .long, help: "人类可读格式输出")
    var human = false

    func run() async throws {
        if region != nil && app != nil {
            Output.error("--app 和 --region 不能同时使用")
            throw ExitCode.failure
        }

        let elements: [OCRTextElement]

        if let regionStr = region {
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

    private func ocrRegion(_ regionStr: String) async throws -> [OCRTextElement] {
        let parts = regionStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else {
            Output.error("区域格式错误，使用 'x,y,w,h'")
            throw ExitCode.failure
        }
        let rect = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        let image = try await OCREngine.captureRegion(rect)
        return try OCREngine.recognize(image: image, screenRect: rect)
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
