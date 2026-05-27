import ArgumentParser

struct ClipboardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clipboard", abstract: "读写系统剪贴板")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
