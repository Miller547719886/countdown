public enum CapturePanelKeyboardBehavior {
    public static let spaceKeyCode: UInt16 = 49

    public static func shouldToggleSaveScreenshot(
        keyCode: UInt16,
        hasModifier: Bool,
        isKeyWindow: Bool,
        isFormControlFocused: Bool
    ) -> Bool {
        keyCode == spaceKeyCode
            && !hasModifier
            && isKeyWindow
            && !isFormControlFocused
    }
}
