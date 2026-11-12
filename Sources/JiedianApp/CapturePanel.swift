import AppKit
import JiedianCore

@MainActor
final class CapturePanel: NSPanel {
    var onPlainSpace: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let hasModifier = !event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .isEmpty
        let isFormControlFocused = firstResponderIsFormControl

        if CapturePanelKeyboardBehavior.shouldToggleSaveScreenshot(
            keyCode: event.keyCode,
            hasModifier: hasModifier,
            isKeyWindow: isKeyWindow,
            isFormControlFocused: isFormControlFocused
        ) {
            onPlainSpace?()
            return
        }

        super.keyDown(with: event)
    }

    private var firstResponderIsFormControl: Bool {
        var responder: NSResponder? = firstResponder
        while let current = responder {
            if current is NSControl || current is NSTextView {
                return true
            }
            responder = current.nextResponder
        }
        return false
    }
}
