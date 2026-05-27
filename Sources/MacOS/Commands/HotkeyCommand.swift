import ArgumentParser

struct HotkeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hotkey", abstract: "按下快捷键组合")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
