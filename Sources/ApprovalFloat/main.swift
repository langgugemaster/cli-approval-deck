import AppKit
import ApprovalFloatCore

private enum PixelTheme {
    static let background = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.075, alpha: 0.98)
    static let panel = NSColor(calibratedRed: 0.055, green: 0.085, blue: 0.105, alpha: 1)
    static let border = NSColor(calibratedRed: 0.20, green: 0.95, blue: 0.58, alpha: 1)
    static let mutedBorder = NSColor(calibratedRed: 0.16, green: 0.34, blue: 0.34, alpha: 1)
    static let text = NSColor(calibratedRed: 0.86, green: 1, blue: 0.91, alpha: 1)
    static let mutedText = NSColor(calibratedRed: 0.46, green: 0.68, blue: 0.62, alpha: 1)
    static let alert = NSColor(calibratedRed: 1, green: 0.78, blue: 0.30, alpha: 1)
    static let error = NSColor(calibratedRed: 1, green: 0.38, blue: 0.40, alpha: 1)

    static func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}

private final class PixelBoxView: NSView {
    var borderColor = PixelTheme.mutedBorder
    var fillColor = PixelTheme.panel

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
        borderColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
    }
}

private final class PixelDuckView: NSView {
    var isApprovalRaised = false {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        let pixel: CGFloat = 6
        let originX = floor((bounds.width - (22 * pixel)) / 2)
        let originY: CGFloat = 2

        func block(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: NSColor) {
            color.setFill()
            NSRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: CGFloat(width) * pixel,
                height: CGFloat(height) * pixel
            ).fill()
        }

        let outline = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.17, alpha: 1)
        let duck = NSColor(calibratedRed: 1, green: 0.82, blue: 0.18, alpha: 1)
        let duckLight = NSColor(calibratedRed: 1, green: 0.92, blue: 0.38, alpha: 1)
        let beak = NSColor(calibratedRed: 1, green: 0.48, blue: 0.15, alpha: 1)
        let sign = NSColor(calibratedRed: 0.18, green: 0.92, blue: 0.52, alpha: 1)

        block(6, 0, 11, 2, outline)
        block(4, 2, 15, 2, outline)
        block(3, 4, 16, 5, outline)
        block(5, 9, 10, 5, outline)
        block(17, 7, 4, 3, outline)
        block(5, 2, 13, 6, duck)
        block(6, 8, 8, 5, duckLight)
        block(18, 8, 4, 1, beak)
        block(8, 11, 1, 1, outline)
        block(8, 12, 1, 1, duckLight)
        block(6, 0, 2, 2, beak)
        block(14, 0, 2, 2, beak)

        if isApprovalRaised {
            block(2, 8, 2, 7, outline)
            block(1, 15, 10, 1, outline)
            block(1, 21, 10, 1, outline)
            block(0, 16, 1, 5, outline)
            block(11, 16, 1, 5, outline)
            block(1, 16, 10, 5, sign)
            block(3, 18, 2, 1, outline)
            block(4, 17, 2, 1, outline)
            block(5, 18, 1, 1, outline)
            block(6, 19, 3, 1, outline)
        } else {
            block(2, 4, 2, 4, outline)
            block(0, 0, 8, 1, outline)
            block(0, 4, 8, 1, outline)
            block(0, 1, 1, 3, outline)
            block(7, 1, 1, 3, outline)
            block(1, 1, 6, 3, PixelTheme.panel)
            block(2, 2, 4, 1, PixelTheme.mutedBorder)
        }
    }
}

private final class PixelButton: NSButton {
    private var isHovered = false

    init(title: String, target: AnyObject?, action: Selector?, height: CGFloat = 30) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        setButtonType(.momentaryPushIn)
        isBordered = false
        font = PixelTheme.font(size: 12, weight: .bold)
        alignment = .left
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 2
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        refreshColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet { refreshColors() }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshColors()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self
        ))
    }

    private func refreshColors() {
        let border = isEnabled ? PixelTheme.border : PixelTheme.mutedBorder
        contentTintColor = isEnabled ? PixelTheme.text : PixelTheme.mutedText
        layer?.borderColor = border.cgColor
        layer?.backgroundColor = isHovered && isEnabled
            ? PixelTheme.mutedBorder.cgColor
            : PixelTheme.background.cgColor
    }
}

@MainActor private func makeLabel(
    _ text: String,
    size: CGFloat,
    color: NSColor,
    weight: NSFont.Weight = .regular
) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = PixelTheme.font(size: size, weight: weight)
    label.textColor = color
    return label
}

final class ApprovalPanelController: NSWindowController {
    private let store = ApprovalStore()
    private let statusDot = makeLabel("[*]", size: 13, color: PixelTheme.border, weight: .bold)
    private let statusLabel = makeLabel("SCANNING FOR CLI REQUESTS", size: 13, color: PixelTheme.text, weight: .bold)
    private let queueLabel = makeLabel("[ QUEUE 0 ]", size: 11, color: PixelTheme.mutedText, weight: .bold)
    private let commandLabel = makeLabel("WAITING FOR CODEX OR CLAUDE...", size: 11, color: PixelTheme.mutedText)
    private let promptLabel = makeLabel("PTY MONITOR ONLINE", size: 11, color: PixelTheme.text)
    private let duckView = PixelDuckView()
    private var confirmButton: PixelButton?
    private var pendingApprovals: [PendingApproval] = []
    private var pending: PendingApproval?
    private var timer: Timer?
    private var isPanelVisible = true

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 493),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.center()

        super.init(window: panel)
        panel.contentView = makeContentView()
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 0.35,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeContentView() -> NSView {
        let content = NSView()
        let panelBox = PixelBoxView()
        panelBox.borderColor = PixelTheme.border
        panelBox.fillColor = PixelTheme.background
        panelBox.translatesAutoresizingMaskIntoConstraints = false
        duckView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(panelBox)
        content.addSubview(duckView)

        let titleLabel = makeLabel(":: CLI APPROVAL DECK ::", size: 14, color: PixelTheme.border, weight: .heavy)
        let hideButton = PixelButton(title: "[ _ ]", target: self, action: #selector(hidePanel))
        hideButton.alignment = .center
        hideButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let closeButton = PixelButton(title: "[ X ]", target: self, action: #selector(closePanel))
        closeButton.alignment = .center
        closeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let titleRow = NSStackView(views: [titleLabel, NSView(), hideButton, closeButton])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        let statusRow = NSStackView(views: [statusDot, statusLabel, NSView(), queueLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 7

        commandLabel.lineBreakMode = .byTruncatingMiddle
        promptLabel.maximumNumberOfLines = 10
        promptLabel.lineBreakMode = .byWordWrapping
        promptLabel.cell?.wraps = true

        let promptBox = PixelBoxView()
        promptBox.translatesAutoresizingMaskIntoConstraints = false
        promptBox.addSubview(promptLabel)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            promptBox.heightAnchor.constraint(equalToConstant: 158),
            promptLabel.leadingAnchor.constraint(equalTo: promptBox.leadingAnchor, constant: 10),
            promptLabel.trailingAnchor.constraint(equalTo: promptBox.trailingAnchor, constant: -10),
            promptLabel.topAnchor.constraint(equalTo: promptBox.topAnchor, constant: 9)
        ])

        let confirmButton = PixelButton(
            title: "[ APPROVE REQUEST ]",
            target: self,
            action: #selector(confirmApproval),
            height: 54
        )
        confirmButton.alignment = .center
        confirmButton.isEnabled = false
        self.confirmButton = confirmButton

        let footer = makeLabel("DRAG TO MOVE  //  ALWAYS ON TOP  //  LIVE PTY LINK", size: 9, color: PixelTheme.mutedText)
        let stack = NSStackView(views: [titleRow, statusRow, commandLabel, promptBox, confirmButton, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        panelBox.addSubview(stack)
        NSLayoutConstraint.activate([
            duckView.topAnchor.constraint(equalTo: content.topAnchor),
            duckView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            duckView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            duckView.heightAnchor.constraint(equalToConstant: 138),
            panelBox.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            panelBox.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            panelBox.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            panelBox.heightAnchor.constraint(equalToConstant: 355),
            stack.leadingAnchor.constraint(equalTo: panelBox.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panelBox.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panelBox.topAnchor, constant: 12),
            promptBox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            confirmButton.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return content
    }

    @objc private func refresh() {
        if isPanelVisible {
            window?.orderFrontRegardless()
        }
        do {
            pendingApprovals = try store.loadPending()
        } catch {
            pendingApprovals = []
            pending = nil
            statusDot.stringValue = "[!]"
            statusDot.textColor = PixelTheme.error
            statusLabel.stringValue = "MONITOR ERROR"
            promptLabel.stringValue = error.localizedDescription
        }
        guard !pendingApprovals.isEmpty else {
            pending = nil
            duckView.isApprovalRaised = false
            statusDot.stringValue = "[*]"
            statusDot.textColor = PixelTheme.border
            statusLabel.stringValue = "SCANNING FOR CLI REQUESTS"
            queueLabel.stringValue = "[ QUEUE 0 ]"
            commandLabel.stringValue = "WAITING FOR CODEX OR CLAUDE..."
            promptLabel.stringValue = "PTY MONITOR ONLINE\nNO APPROVAL REQUESTS DETECTED"
            updateConfirmButton(with: nil)
            return
        }
        let pending = pendingApprovals[0]
        self.pending = pending
        duckView.isApprovalRaised = true
        statusDot.stringValue = "[!]"
        statusDot.textColor = PixelTheme.alert
        statusLabel.stringValue = "AUTHORIZATION REQUIRED"
        queueLabel.stringValue = "[ QUEUE \(pendingApprovals.count) ]"
        commandLabel.stringValue = "> \(pending.command)"
        promptLabel.stringValue = pending.prompt
        updateConfirmButton(with: pending.approveOption)
    }

    private func updateConfirmButton(with option: ApprovalOption?) {
        confirmButton?.title = option == nil
            ? "[ APPROVE REQUEST ] AWAITING REQUEST..."
            : "[ APPROVE REQUEST ]"
        confirmButton?.isEnabled = option != nil
    }

    @objc private func confirmApproval() {
        guard let pending, let option = pending.approveOption else { return }
        do {
            try store.submit(option, for: pending)
            statusLabel.stringValue = "APPROVAL TRANSMITTED"
        } catch {
            statusDot.stringValue = "[!]"
            statusDot.textColor = PixelTheme.error
            statusLabel.stringValue = "TRANSMISSION FAILED"
            promptLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func closePanel() {
        NSApp.terminate(nil)
    }

    @objc func hidePanel() {
        isPanelVisible = false
        window?.orderOut(nil)
    }

    @objc func showPanel() {
        isPanelVisible = true
        window?.orderFrontRegardless()
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: ApprovalPanelController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = ApprovalPanelController()
        panelController?.showPanel()
        makeStatusItem()
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "[A]"
        item.button?.font = PixelTheme.font(size: 11, weight: .bold)
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Floating Panel", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Hide Floating Panel", action: #selector(hidePanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit CLI Approval Deck", action: #selector(quitApp), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func showPanel() {
        panelController?.showPanel()
    }

    @objc private func hidePanel() {
        panelController?.hidePanel()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
