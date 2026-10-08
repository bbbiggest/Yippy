import Cocoa

final class SearchFieldCell: NSTextFieldCell {
    private func centeredFrame(_ frame: NSRect) -> NSRect {
        let height = min(frame.height, cellSize(forBounds: frame).height)
        return NSRect(x: frame.minX, y: frame.midY - height / 2,
                      width: frame.width, height: height)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: centeredFrame(cellFrame), in: controlView)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                       delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: centeredFrame(rect), in: controlView, editor: textObj,
                   delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                         delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: centeredFrame(rect), in: controlView, editor: textObj,
                     delegate: delegate, start: selStart, length: selLength)
    }
}
