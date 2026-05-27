import ArgumentParser

struct WindowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "window", abstract: "管理窗口")
    func run() async throws { print("{\"error\": \"not implemented\"}") }
}
