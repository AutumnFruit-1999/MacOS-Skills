import Vision
import CoreGraphics
import ScreenCaptureKit

struct OCRTextElement: Codable, Sendable {
    let text: String
    let confidence: Double
    let frame: ElementFrame

    struct ElementFrame: Codable, Sendable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
    }
}

enum OCRError: Error, CustomStringConvertible {
    case captureFailure
    var description: String {
        switch self {
        case .captureFailure: return "屏幕区域截图失败"
        }
    }
}

final class OCREngine: @unchecked Sendable {

    static func recognize(image: CGImage, screenRect: CGRect? = nil) throws -> [OCRTextElement] {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)

        var results: [OCRTextElement] = []

        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let box = observation.boundingBox
            var x = box.origin.x * imgW
            var y = (1.0 - box.origin.y - box.height) * imgH
            var w = box.width * imgW
            var h = box.height * imgH

            if let rect = screenRect {
                let sx = rect.width / imgW
                let sy = rect.height / imgH
                x = rect.origin.x + x * sx
                y = rect.origin.y + y * sy
                w = w * sx
                h = h * sy
            }

            results.append(OCRTextElement(
                text: candidate.string,
                confidence: Double(round(Double(candidate.confidence) * 1000) / 1000),
                frame: .init(x: round(x), y: round(y), w: round(w), h: round(h))
            ))
        }

        return results
    }

    static func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw OCRError.captureFailure
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
