import AppKit
import SwiftUI

private final class InsetPopupButtonCell: NSPopUpButtonCell {

    private let titleLeftInset: CGFloat = 18
    private let titleRightInset: CGFloat = 38
    private let arrowRightInset: CGFloat = 14
    private let arrowWidth: CGFloat = 7
    private let arrowHeight: CGFloat = 3
    private let arrowSpacing: CGFloat = 3

    override func drawBorderAndBackground(
        withFrame cellFrame: NSRect,
        in controlView: NSView
    ) {
        // SwiftUI wrapper 负责绘制背景和边框。
    }

    override func titleRect(forBounds cellFrame: NSRect) -> NSRect {
        let defaultRect = super.titleRect(forBounds: cellFrame)

        let left = max(
            defaultRect.minX,
            cellFrame.minX + titleLeftInset
        )

        // 为右侧上下双箭头预留空间
        let right = min(
            defaultRect.maxX,
            cellFrame.maxX - titleRightInset
        )

        return NSRect(
            x: left,
            y: defaultRect.minY,
            width: max(0, right - left),
            height: defaultRect.height
        )
    }

    override func drawInterior(
        withFrame cellFrame: NSRect,
        in controlView: NSView
    ) {
        // 绘制标题
        super.drawInterior(
            withFrame: cellFrame,
            in: controlView
        )

        // 绘制右侧 macOS 风格上下双箭头
        drawDoubleChevron(
            in: cellFrame,
            enabled: isEnabled
        )
    }

    private func drawDoubleChevron(
        in cellFrame: NSRect,
        enabled: Bool
    ) {
        let centerX = cellFrame.maxX - arrowRightInset
        let centerY = cellFrame.midY

        let halfWidth = arrowWidth / 2
        let halfHeight = arrowHeight / 2
        let verticalOffset = arrowSpacing

        let path = NSBezierPath()
        path.lineWidth = 1.25
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // 上箭头：⌃
        let upperCenterY = centerY + verticalOffset

        path.move(
            to: NSPoint(
                x: centerX - halfWidth,
                y: upperCenterY - halfHeight
            )
        )

        path.line(
            to: NSPoint(
                x: centerX,
                y: upperCenterY + halfHeight
            )
        )

        path.line(
            to: NSPoint(
                x: centerX + halfWidth,
                y: upperCenterY - halfHeight
            )
        )

        // 下箭头：⌄
        let lowerCenterY = centerY - verticalOffset

        path.move(
            to: NSPoint(
                x: centerX - halfWidth,
                y: lowerCenterY + halfHeight
            )
        )

        path.line(
            to: NSPoint(
                x: centerX,
                y: lowerCenterY - halfHeight
            )
        )

        path.line(
            to: NSPoint(
                x: centerX + halfWidth,
                y: lowerCenterY + halfHeight
            )
        )

        let arrowColor: NSColor = enabled
            ? .secondaryLabelColor
            : .disabledControlTextColor

        arrowColor.setStroke()
        path.stroke()
    }
}

final class AnchoredPopupButton: NSPopUpButton {

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: 36
        )
    }

    override func mouseDown(with event: NSEvent) {
        openMenu()
    }

    override func performClick(_ sender: Any?) {
        openMenu()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 49, 125, 126:
            // Return、Space、向下、向上
            openMenu()

        default:
            super.keyDown(with: event)
        }
    }

    private func openMenu() {
        guard
            isEnabled,
            let menu,
            menu.numberOfItems > 0
        else {
            return
        }

        // 菜单宽度至少与整个控件相同
        menu.minimumWidth = max(
            menu.minimumWidth,
            bounds.width
        )

        _ = menu.popUp(
            positioning: nil,
            at: NSPoint(
                x: bounds.minX,
                y: bounds.minY
            ),
            in: self
        )
    }
}

struct NativePopupButton: NSViewRepresentable {

    let titles: [String]

    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(
        context: Context
    ) -> AnchoredPopupButton {
        let button = AnchoredPopupButton(
            frame: .zero,
            pullsDown: false
        )

        button.cell = InsetPopupButtonCell(
            textCell: "",
            pullsDown: false
        )

        button.isBordered = false
        button.isTransparent = false

        button.cell?.isBordered = false
        button.cell?.isBezeled = false

        button.controlSize = .regular
        button.alignment = .left
        button.font = .systemFont(ofSize: 14)
        button.contentTintColor = .labelColor
        button.focusRingType = .none
        button.autoenablesItems = false
        button.preferredEdge = .maxY

        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor

        button.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        button.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        button.setContentHuggingPriority(
            .defaultLow,
            for: .vertical
        )

        button.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        context.coordinator.button = button

        updateItems(
            in: button,
            coordinator: context.coordinator
        )

        return button
    }

    func updateNSView(
        _ button: AnchoredPopupButton,
        context: Context
    ) {
        context.coordinator.selection = $selection
        context.coordinator.button = button

        updateItems(
            in: button,
            coordinator: context.coordinator
        )

        // selection 或 enabled 状态改变时重绘箭头
        button.needsDisplay = true
    }

    private func updateItems(
        in button: NSPopUpButton,
        coordinator: Coordinator
    ) {
        coordinator.itemIndices = Array(titles.indices)

        button.removeAllItems()

        guard !titles.isEmpty else {
            button.addItem(withTitle: "请选择主机")
            button.selectItem(at: 0)
            button.isEnabled = false
            button.needsDisplay = true
            return
        }

        button.isEnabled = true
        button.addItems(withTitles: titles)

        let index = min(
            max(selection, 0),
            titles.count - 1
        )

        button.selectItem(at: index)

        if let cell = button.cell as? NSPopUpButtonCell {
            cell.pullsDown = false
            cell.usesItemFromMenu = true
            cell.altersStateOfSelectedItem = true
        }

        if let menu = button.menu {
            menu.autoenablesItems = false
            menu.showsStateColumn = true
            menu.font = .systemFont(ofSize: 13)

            menu.minimumWidth = max(
                menu.minimumWidth,
                button.bounds.width
            )

            for (itemIndex, item) in menu.items.enumerated() {
                item.tag = itemIndex
                item.target = coordinator
                item.action = #selector(
                    Coordinator.menuItemSelected(_:)
                )

                item.state = itemIndex == index
                    ? .on
                    : .off
            }
        }

        button.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject {

        var selection: Binding<Int>
        var itemIndices: [Int] = []

        weak var button: NSPopUpButton?

        init(selection: Binding<Int>) {
            self.selection = selection
        }

        @objc
        func menuItemSelected(_ sender: NSMenuItem) {
            let index = sender.tag

            guard itemIndices.indices.contains(index) else {
                return
            }

            button?.selectItem(at: index)

            for (itemIndex, item) in
                (button?.menu?.items ?? []).enumerated() {
                item.state = itemIndex == index
                    ? .on
                    : .off
            }

            selection.wrappedValue = itemIndices[index]
            button?.needsDisplay = true
        }
    }
}
