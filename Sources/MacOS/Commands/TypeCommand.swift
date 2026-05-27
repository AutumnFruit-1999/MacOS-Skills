import ArgumentParser

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "输入文本到 UI 元素或当前焦点")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
