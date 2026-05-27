import ArgumentParser

struct ClickCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "click", abstract: "点击 UI 元素或坐标")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
