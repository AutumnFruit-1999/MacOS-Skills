import ArgumentParser

struct ScrollCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scroll", abstract: "向任意方向滚动")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
