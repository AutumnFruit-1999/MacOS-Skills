import ApplicationServices
import AppKit

struct UIElement: Codable, Sendable {
    let id: String
    let role: String
    let title: String?
    let value: String?
    let frame: Frame?
    let actions: [String]?

    struct Frame: Codable, Sendable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
    }
}

final class AccessibilityEngine: @unchecked Sendable {
    private let maxDepth: Int
    private let maxElements: Int

    init(maxDepth: Int = 10, maxElements: Int = 500) {
        self.maxDepth = maxDepth
        self.maxElements = maxElements
    }

    func findApp(name: String) -> pid_t? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { $0.localizedName == name }?.processIdentifier
    }

    func frontmostApp() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func discoverElements(pid: pid_t) -> [UIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var elements: [UIElement] = []
        var counters: [String: Int] = [:]
        traverse(element: appElement, depth: 0, elements: &elements, counters: &counters)
        return elements
    }

    func getTree(pid: pid_t, maxDepth: Int? = nil) -> [String: Any] {
        let appElement = AXUIElementCreateApplication(pid)
        return buildTree(element: appElement, depth: 0, maxDepth: maxDepth ?? self.maxDepth)
    }

    private func traverse(element: AXUIElement, depth: Int, elements: inout [UIElement], counters: inout [String: Int]) {
        guard depth < maxDepth, elements.count < maxElements else { return }

        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        let value = getAttribute(element, kAXValueAttribute) as? String
        let actions = getActions(element)

        if isInteractive(role: role) {
            let prefix = idPrefix(for: role)
            let count = (counters[prefix] ?? 0) + 1
            counters[prefix] = count
            let id = "\(prefix)\(count)"
            let frame = getFrame(element)
            elements.append(UIElement(id: id, role: role, title: title, value: value, frame: frame, actions: actions.isEmpty ? nil : actions))
        }

        guard let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
        for child in children {
            traverse(element: child, depth: depth + 1, elements: &elements, counters: &counters)
        }
    }

    private func buildTree(element: AXUIElement, depth: Int, maxDepth: Int) -> [String: Any] {
        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        var node: [String: Any] = ["role": role]
        if let title = title { node["title"] = title }
        if depth < maxDepth, let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            node["children"] = children.map { buildTree(element: $0, depth: depth + 1, maxDepth: maxDepth) }
        }
        return node
    }

    private func getAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    private func getActions(_ element: AXUIElement) -> [String] {
        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        return (actions as? [String]) ?? []
    }

    private func getFrame(_ element: AXUIElement) -> UIElement.Frame? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard let posValue = posValue, let sizeValue = sizeValue else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return UIElement.Frame(x: point.x, y: point.y, w: size.width, h: size.height)
    }

    private func isInteractive(role: String) -> Bool {
        [
            "AXButton", "AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton",
            "AXPopUpButton", "AXComboBox", "AXSlider", "AXMenuButton", "AXLink",
            "AXTab", "AXIncrementor",
        ].contains(role)
    }

    private func idPrefix(for role: String) -> String {
        switch role {
        case "AXButton", "AXMenuButton": return "B"
        case "AXTextField", "AXTextArea", "AXComboBox": return "T"
        case "AXCheckBox", "AXRadioButton": return "C"
        case "AXLink": return "L"
        case "AXSlider", "AXIncrementor": return "S"
        case "AXTab": return "Tab"
        case "AXPopUpButton": return "P"
        default: return "E"
        }
    }
}
