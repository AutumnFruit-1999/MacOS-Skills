import ArgumentParser

struct HotkeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "hotkey", abstract: "按下快捷键组合（如 cmd,c）")

    @Option(name: .long, help: "逗号分隔的按键组合（如 'cmd,c'、'cmd,shift,t'）")
    var keys: String

    func run() throws {
        try Permissions.ensureAccessibility()
        let keyParts = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        try EventEngine.hotkey(keys: keyParts)
        Output.printCodable(HotkeyResult(pressed: keys))
    }
}

struct HotkeyResult: Codable {
    let pressed: String
}
