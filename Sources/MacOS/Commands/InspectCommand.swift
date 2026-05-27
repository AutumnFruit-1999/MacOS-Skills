import ArgumentParser

struct InspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "inspect", abstract: "查看原始 AX 树结构")
    func run() async throws { print("{\"error\": \"not implemented\"}") }
}
