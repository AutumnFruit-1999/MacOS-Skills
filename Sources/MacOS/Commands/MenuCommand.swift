import ArgumentParser

struct MenuCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "menu", abstract: "操作应用菜单栏")
    func run() throws { print("{\"error\": \"not implemented\"}") }
}
