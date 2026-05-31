import AppKit
import ApprovalFloatCore

final class ApprovalPanelController: NSWindowController {
    private let store = ApprovalStore()
    private let statusLabel = NSTextField(labelWithString: "等待 CLI 授权请求")
    private let commandLabel = NSTextField(labelWithString: "请用 cli-approval-run 启动命令")
    private let promptLabel = NSTextField(wrappingLabelWithString: "")
    private var buttons: [NSButton] = []
    private var pending: PendingApproval?
    private var timer: Timer?

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 230),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "CLI 授权确认"
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
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
        statusLabel.font = .boldSystemFont(ofSize: 15)
        commandLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        commandLabel.textColor = .secondaryLabelColor
        commandLabel.lineBreakMode = .byTruncatingMiddle
        promptLabel.font = .systemFont(ofSize: 12)
        promptLabel.maximumNumberOfLines = 4

        let buttonStack = NSStackView()
        buttonStack.orientation = .vertical
        buttonStack.spacing = 6
        for index in 0..<3 {
            let button = NSButton(title: "选项 \(index + 1)", target: self, action: #selector(selectOption(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.isEnabled = false
            buttons.append(button)
            buttonStack.addArrangedSubview(button)
        }

        let stack = NSStackView(views: [statusLabel, commandLabel, promptLabel, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            buttonStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return content
    }

    @objc private func refresh() {
        window?.orderFrontRegardless()
        do {
            pending = try store.loadPending()
        } catch {
            pending = nil
            statusLabel.stringValue = "读取授权请求失败"
            promptLabel.stringValue = error.localizedDescription
        }
        guard let pending else {
            statusLabel.stringValue = "等待 CLI 授权请求"
            commandLabel.stringValue = "请用 cli-approval-run 启动命令"
            promptLabel.stringValue = ""
            updateButtons(with: [])
            return
        }
        statusLabel.stringValue = "有待确认的授权请求"
        commandLabel.stringValue = pending.command
        promptLabel.stringValue = pending.prompt
        updateButtons(with: pending.options)
    }

    private func updateButtons(with options: [ApprovalOption]) {
        for (index, button) in buttons.enumerated() {
            if index < options.count {
                button.title = "\(options[index].key). \(options[index].label)"
                button.isEnabled = true
            } else {
                button.title = "选项 \(index + 1)"
                button.isEnabled = false
            }
        }
    }

    @objc private func selectOption(_ sender: NSButton) {
        guard let pending, sender.tag < pending.options.count else {
            return
        }
        do {
            try store.submit(pending.options[sender.tag], for: pending)
            statusLabel.stringValue = "已提交选项 \(pending.options[sender.tag].key)"
        } catch {
            statusLabel.stringValue = "提交失败：\(error.localizedDescription)"
        }
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
