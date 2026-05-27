import ArgumentParser

@main
struct MacOS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "macos",
        abstract: "macOS 自动化 CLI — 通过 Apple 原生 API 控制桌面",
        subcommands: [
            SeeCommand.self,
            InspectCommand.self,
            ClickCommand.self,
            TypeCommand.self,
            HotkeyCommand.self,
            ScrollCommand.self,
            AppCommand.self,
            WindowCommand.self,
            MenuCommand.self,
            ClipboardCommand.self,
            OcrCommand.self,
        ]
    )
}
