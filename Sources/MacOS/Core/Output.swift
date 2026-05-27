import Foundation

enum OutputFormat {
    case json
    case human
}

struct Output {
    static func print(_ value: Any, format: OutputFormat = .json) {
        switch format {
        case .json:
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        case .human:
            Swift.print(value)
        }
    }

    static func printCodable<T: Encodable>(_ value: T, format: OutputFormat = .json) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            Swift.print(str)
        }
    }

    static func error(_ message: String) {
        let err: [String: String] = ["error": message]
        if let data = try? JSONSerialization.data(withJSONObject: err, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            fputs(str + "\n", stderr)
        }
    }
}
