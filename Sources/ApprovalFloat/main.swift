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

private final class PixelButton: NSButton {
    init(title: String, target: AnyObject?, action: Selector?, height: CGFloat = 30) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
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
        layer?.backgroundColor = PixelTheme.mutedBorder.cgColor
    }

    override func mouseExited(with event: NSEvent) {
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
        layer?.backgroundColor = PixelTheme.background.cgColor
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
    private var confirmButton: PixelButton?
    private var pendingApprovals: [PendingApproval] = []
    private var pending: PendingApproval?
    private var timer: Timer?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 265),
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
        let content = PixelBoxView()
        content.borderColor = PixelTheme.border
        content.fillColor = PixelTheme.background

        let titleLabel = makeLabel(":: CLI APPROVAL DECK ::", size: 14, color: PixelTheme.border, weight: .heavy)
        let closeButton = PixelButton(title: "[ X ]", target: self, action: #selector(closePanel))
        closeButton.alignment = .center
        closeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let titleRow = NSStackView(views: [titleLabel, NSView(), closeButton])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        let statusRow = NSStackView(views: [statusDot, statusLabel, NSView(), queueLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 7

        commandLabel.lineBreakMode = .byTruncatingMiddle
        promptLabel.maximumNumberOfLines = 5
        promptLabel.lineBreakMode = .byWordWrapping
        promptLabel.cell?.wraps = true

        let promptBox = PixelBoxView()
        promptBox.translatesAutoresizingMaskIntoConstraints = false
        promptBox.addSubview(promptLabel)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            promptBox.heightAnchor.constraint(equalToConstant: 76),
            promptLabel.leadingAnchor.constraint(equalTo: promptBox.leadingAnchor, constant: 10),
            promptLabel.trailingAnchor.constraint(equalTo: promptBox.trailingAnchor, constant: -10),
            promptLabel.topAnchor.constraint(equalTo: promptBox.topAnchor, constant: 9)
        ])

        let confirmButton = PixelButton(
            title: "[ APPROVE ] AWAITING REQUEST...",
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
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            promptBox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            confirmButton.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return content
    }

    @objc private func refresh() {
        window?.orderFrontRegardless()
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
        statusDot.stringValue = "[!]"
        statusDot.textColor = PixelTheme.alert
        statusLabel.stringValue = "AUTHORIZATION REQUIRED"
        queueLabel.stringValue = "[ QUEUE \(pendingApprovals.count) ]"
        commandLabel.stringValue = "> \(pending.command)"
        promptLabel.stringValue = pending.prompt
        updateConfirmButton(with: pending.options.first)
    }

    private func updateConfirmButton(with option: ApprovalOption?) {
        if let option {
            confirmButton?.title = "[ APPROVE ] CONFIRM // \(option.label.uppercased())"
            confirmButton?.isEnabled = true
        } else {
            confirmButton?.title = "[ APPROVE ] AWAITING REQUEST..."
            confirmButton?.isEnabled = false
        }
    }

    @objc private func confirmApproval() {
        guard let pending, let option = pending.options.first else { return }
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
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: ApprovalPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = ApprovalPanelController()
        panelController?.showWindow(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
