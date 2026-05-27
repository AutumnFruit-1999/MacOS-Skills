import ArgumentParser
import CoreGraphics

struct ScrollCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scroll", abstract: "向任意方向滚动")

    @Option(name: .long, help: "方向: up, down, left, right")
    var direction: String

    @Option(name: .long, help: "滚动行数（默认 3）")
    var amount: Int32 = 3

    @Option(name: .long, help: "在指定坐标滚动 'x,y'")
    var coords: String?

    func run() throws {
        try Permissions.ensureAccessibility()
        guard let dir = EventEngine.ScrollDirection(rawValue: direction.lowercased()) else {
            Output.error("无效方向，使用: up, down, left, right")
            throw ExitCode.failure
        }
        if let coordStr = coords {
            let parts = coordStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                EventEngine.moveMouse(to: CGPoint(x: parts[0], y: parts[1]))
                usleep(50_000)
            }
        }
        EventEngine.scroll(direction: dir, amount: amount)
        Output.printCodable(ScrollResult(direction: direction, amount: amount))
    }
}

struct ScrollResult: Codable {
    let direction: String
    let amount: Int32
}
