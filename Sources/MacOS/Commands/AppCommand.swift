import ArgumentParser

struct AppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "app", abstract: "管理应用（启动/退出/聚焦/列表）")
    func run() async throws { print("{\"error\": \"not implemented\"}") }
}
