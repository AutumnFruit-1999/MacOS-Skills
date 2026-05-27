import ArgumentParser
import ApplicationServices
import AppKit

struct MenuCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "menu", abstract: "操作应用菜单栏")

    @Option(name: .long, help: "操作: list, click")
    var action: String

    @Option(name: .long, help: "目标应用名")
    var app: String

    @Option(name: .long, help: "菜单路径（如 'File > Save'）")
    var path: String?

    func run() throws {
        try Permissions.ensureAccessibility()

        let engine = AccessibilityEngine()
        guard let pid = engine.findApp(name: app) else {
            Output.error("应用未找到: \(app)")
            throw ExitCode.failure
        }

        let appElement = AXUIElementCreateApplication(pid)

        switch action.lowercased() {
        case "list":
            let items = listMenuItems(appElement: appElement)
            Output.printCodable(items)

        case "click":
            guard let menuPath = path else {
                Output.error("click 需要 --path（如 'File > Save'）")
                throw ExitCode.failure
            }
            try clickMenuItem(appElement: appElement, path: menuPath)
            Output.printCodable(MenuResult(action: "click", path: menuPath, success: true))

        default:
            Output.error("未知操作: \(action)，使用: list, click")
            throw ExitCode.failure
        }
    }

    private func listMenuItems(appElement: AXUIElement) -> [MenuItem] {
        var menuBarRef: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard let menuBar = menuBarRef as! AXUIElement? else { return [] }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef)
        guard let menus = childrenRef as? [AXUIElement] else { return [] }

        var items: [MenuItem] = []
        for menu in menus {
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(menu, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            if title.isEmpty { continue }

            var subItems: [String] = []
            var subRef: AnyObject?
            AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &subRef)
            if let subMenus = subRef as? [AXUIElement] {
                for sub in subMenus {
                    var subChildrenRef: AnyObject?
                    AXUIElementCopyAttributeValue(sub, kAXChildrenAttribute as CFString, &subChildrenRef)
                    if let subChildren = subChildrenRef as? [AXUIElement] {
                        for item in subChildren {
                            var itemTitleRef: AnyObject?
                            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &itemTitleRef)
                            if let itemTitle = itemTitleRef as? String, !itemTitle.isEmpty {
                                subItems.append(itemTitle)
                            }
                        }
                    }
                }
            }
            items.append(MenuItem(menu: title, items: subItems))
        }
        return items
    }

    private func clickMenuItem(appElement: AXUIElement, path: String) throws {
        let parts = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else {
            throw MenuError.invalidPath(path)
        }

        var menuBarRef: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard menuBarRef != nil else { throw MenuError.noMenuBar }

        var current: AXUIElement = menuBarRef as! AXUIElement
        for part in parts {
            guard let next = findChild(of: current, title: part) else {
                throw MenuError.itemNotFound(part)
            }
            AXUIElementPerformAction(next, kAXPressAction as CFString)
            usleep(100_000)
            current = next
        }
    }

    private func findChild(of element: AXUIElement, title: String) -> AXUIElement? {
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            if let childTitle = titleRef as? String, childTitle == title { return child }
            if let found = findChild(of: child, title: title) { return found }
        }
        return nil
    }
}

struct MenuItem: Codable {
    let menu: String
    let items: [String]
}

struct MenuResult: Codable {
    let action: String
    let path: String
    let success: Bool
}

enum MenuError: Error, CustomStringConvertible {
    case invalidPath(String)
    case noMenuBar
    case itemNotFound(String)

    var description: String {
        switch self {
        case .invalidPath(let p): return "无效菜单路径: '\(p)'，使用 'Menu > Item' 格式"
        case .noMenuBar: return "未找到菜单栏"
        case .itemNotFound(let item): return "菜单项未找到: '\(item)'"
        }
    }
}
