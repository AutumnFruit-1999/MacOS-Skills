import ApplicationServices
import AppKit

struct UIElement: Codable, Sendable {
    let id: String
    let role: String
    let title: String?
    let value: String?
    let frame: Frame?
    let actions: [String]?
    let description: String?
    let placeholder: String?
    let help: String?
    let subrole: String?
    let domId: String?
    let domClass: String?

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

    enum DiscoverMode { case interactive, webContent, all }

    func discoverElements(pid: pid_t, webContent: Bool = false) -> [UIElement] {
        return discoverElements(pid: pid, mode: webContent ? .webContent : .interactive)
    }

    func discoverElements(pid: pid_t, mode: DiscoverMode) -> [UIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var elements: [UIElement] = []
        var counters: [String: Int] = [:]
        traverse(element: appElement, depth: 0, elements: &elements, counters: &counters, insideWebArea: false, mode: mode)
        return elements
    }

    func getTree(pid: pid_t, maxDepth: Int? = nil, detailed: Bool = false) -> [String: Any] {
        let appElement = AXUIElementCreateApplication(pid)
        return buildTree(element: appElement, depth: 0, maxDepth: maxDepth ?? self.maxDepth, detailed: detailed)
    }

    private func traverse(element: AXUIElement, depth: Int, elements: inout [UIElement], counters: inout [String: Int], insideWebArea: Bool, mode: DiscoverMode) {
        guard depth < maxDepth, elements.count < maxElements else { return }

        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        let value = getAttribute(element, kAXValueAttribute) as? String
        let actions = getActions(element)
        let inWeb = insideWebArea || role == "AXWebArea"

        let shouldCollect: Bool
        switch mode {
        case .interactive:
            shouldCollect = isInteractive(role: role)
        case .webContent:
            shouldCollect = isInteractive(role: role) || (inWeb && isWebContent(role: role))
        case .all:
            shouldCollect = true
        }
        if shouldCollect {
            let prefix = idPrefix(for: role)
            let count = (counters[prefix] ?? 0) + 1
            counters[prefix] = count
            let id = "\(prefix)\(count)"
            let frame = getFrame(element)
            let desc = getAttribute(element, kAXDescriptionAttribute) as? String
            let placeholder = getAttribute(element, "AXPlaceholderValue") as? String
            let help = getAttribute(element, kAXHelpAttribute) as? String
            let subrole = getAttribute(element, kAXSubroleAttribute) as? String
            let domId = getAttribute(element, "AXDOMIdentifier") as? String
            let domClass = getAttribute(element, "AXDOMClassList") as? String
                ?? (getAttribute(element, "AXDOMClassList") as? [String])?.joined(separator: " ")
            elements.append(UIElement(
                id: id, role: role, title: title, value: value, frame: frame,
                actions: actions.isEmpty ? nil : actions, description: desc,
                placeholder: placeholder, help: help, subrole: subrole,
                domId: domId, domClass: domClass
            ))
        }

        guard let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
        for child in children {
            traverse(element: child, depth: depth + 1, elements: &elements, counters: &counters, insideWebArea: inWeb, mode: mode)
        }
    }

    private func buildTree(element: AXUIElement, depth: Int, maxDepth: Int, detailed: Bool) -> [String: Any] {
        let role = getAttribute(element, kAXRoleAttribute) as? String ?? "unknown"
        let title = getAttribute(element, kAXTitleAttribute) as? String
        var node: [String: Any] = ["role": role]
        if let title = title { node["title"] = title }
        if detailed {
            if let value = getAttribute(element, kAXValueAttribute) as? String { node["value"] = value }
            if let desc = getAttribute(element, kAXDescriptionAttribute) as? String { node["description"] = desc }
            if let placeholder = getAttribute(element, "AXPlaceholderValue") as? String { node["placeholder"] = placeholder }
            if let help = getAttribute(element, kAXHelpAttribute) as? String { node["help"] = help }
            if let subrole = getAttribute(element, kAXSubroleAttribute) as? String { node["subrole"] = subrole }
            if let domId = getAttribute(element, "AXDOMIdentifier") as? String { node["domId"] = domId }
            if let frame = getFrame(element) {
                node["frame"] = ["x": frame.x, "y": frame.y, "w": frame.w, "h": frame.h]
            }
        }
        if depth < maxDepth, let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
            node["children"] = children.map { buildTree(element: $0, depth: depth + 1, maxDepth: maxDepth, detailed: detailed) }
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

    private func isWebContent(role: String) -> Bool {
        [
            "AXWebArea", "AXGroup", "AXStaticText", "AXImage", "AXLink",
            "AXList", "AXListItem", "AXHeading", "AXParagraph",
            "AXTextField", "AXTextArea", "AXButton",
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
        case "AXWebArea": return "W"
        case "AXStaticText": return "X"
        case "AXGroup": return "G"
        case "AXImage": return "I"
        case "AXHeading": return "H"
        default: return "E"
        }
    }
}
