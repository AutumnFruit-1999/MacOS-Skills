import ArgumentParser

struct SeeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "see", abstract: "发现可交互 UI 元素（可选截图）")
    func run() async throws { print("{\"error\": \"not implemented\"}") }
}
