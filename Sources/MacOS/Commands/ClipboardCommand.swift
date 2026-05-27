import ArgumentParser
import AppKit

struct ClipboardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "读写系统剪贴板")

    @Option(name: .long, help: "操作: get, set, clear")
    var action: String

    @Option(name: .long, help: "要设置的文本")
    var text: String?

    func run() throws {
        let pb = NSPasteboard.general

        switch action.lowercased() {
        case "get":
            let content = pb.string(forType: .string) ?? ""
            Output.printCodable(ClipboardResult(action: "get", content: content))

        case "set":
            guard let t = text else {
                Output.error("set 需要 --text")
                throw ExitCode.failure
            }
            pb.clearContents()
            pb.setString(t, forType: .string)
            Output.printCodable(ClipboardResult(action: "set", content: t))

        case "clear":
            pb.clearContents()
            Output.printCodable(ClipboardResult(action: "clear", content: nil))

        default:
            Output.error("未知操作: \(action)，使用: get, set, clear")
            throw ExitCode.failure
        }
    }
}

struct ClipboardResult: Codable {
    let action: String
    let content: String?
}
