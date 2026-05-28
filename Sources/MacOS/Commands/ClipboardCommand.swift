import ArgumentParser
import AppKit

struct ClipboardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "读写系统剪贴板")

    @Option(name: .long, help: "操作: get, set, clear")
    var action: String

    @Option(name: .long, help: "要设置的文本（与 --file 互斥）")
    var text: String?

    @Option(name: .long, help: "要复制到剪贴板的文件路径（与 --text 互斥）")
    var file: String?

    func run() throws {
        let pb = NSPasteboard.general

        switch action.lowercased() {
        case "get":
            if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = fileURLs.first {
                let attrs = try? FileManager.default.attributesOfItem(atPath: firstURL.path)
                let size = (attrs?[.size] as? Int) ?? 0
                Output.printCodable(ClipboardResult(action: "get", content: firstURL.path, type: "file", path: firstURL.path, size: size))
            } else {
                let content = pb.string(forType: .string) ?? ""
                Output.printCodable(ClipboardResult(action: "get", content: content, type: "text", path: nil, size: nil))
            }

        case "set":
            if text != nil && file != nil {
                Output.error("--text 和 --file 不能同时使用")
                throw ExitCode.failure
            }
            if let filePath = file {
                let expandedPath = NSString(string: filePath).expandingTildeInPath
                guard FileManager.default.fileExists(atPath: expandedPath) else {
                    Output.error("文件不存在: \(filePath)")
                    throw ExitCode.failure
                }
                let url = URL(fileURLWithPath: expandedPath)
                pb.clearContents()
                pb.writeObjects([url as NSURL])
                let attrs = try? FileManager.default.attributesOfItem(atPath: expandedPath)
                let size = (attrs?[.size] as? Int) ?? 0
                Output.printCodable(ClipboardResult(action: "set", content: filePath, type: "file", path: expandedPath, size: size))
            } else if let t = text {
                pb.clearContents()
                pb.setString(t, forType: .string)
                Output.printCodable(ClipboardResult(action: "set", content: t, type: "text", path: nil, size: nil))
            } else {
                Output.error("set 需要 --text 或 --file")
                throw ExitCode.failure
            }

        case "clear":
            pb.clearContents()
            Output.printCodable(ClipboardResult(action: "clear", content: nil, type: nil, path: nil, size: nil))

        default:
            Output.error("未知操作: \(action)，使用: get, set, clear")
            throw ExitCode.failure
        }
    }
}

struct ClipboardResult: Codable {
    let action: String
    let content: String?
    let type: String?
    let path: String?
    let size: Int?
}
