import ArgumentParser
import CoreGraphics

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "输入文本到 UI 元素或当前焦点")

    @Option(name: .long, help: "要输入的文本")
    var text: String?

    @Option(name: .long, help: "先点击的坐标 'x,y'（聚焦目标）")
    var coords: String?

    @Flag(name: .long, help: "输入前清空字段（Cmd+A, Delete）")
    var clear = false

    @Flag(name: .long, help: "输入后按回车")
    var pressReturn = false

    @Option(name: .long, help: "按键间延迟（毫秒，默认 5）")
    var delay: UInt32 = 5

    func run() throws {
        try Permissions.ensureAccessibility()

        if let coordStr = coords {
            let parts = coordStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                EventEngine.click(at: CGPoint(x: parts[0], y: parts[1]))
                usleep(100_000)
            }
        }

        if clear {
            try EventEngine.hotkey(keys: ["cmd", "a"])
            usleep(50_000)
            EventEngine.pressKey(51)
            usleep(50_000)
        }

        if let text = text {
            EventEngine.typeText(text, delay: delay * 1000)
        }

        if pressReturn {
            EventEngine.pressKey(36)
        }

        Output.printCodable(TypeResult(typed: text ?? "", cleared: clear, pressedReturn: pressReturn))
    }
}

struct TypeResult: Codable {
    let typed: String
    let cleared: Bool
    let pressedReturn: Bool

    enum CodingKeys: String, CodingKey {
        case typed, cleared
        case pressedReturn = "pressed_return"
    }
}
