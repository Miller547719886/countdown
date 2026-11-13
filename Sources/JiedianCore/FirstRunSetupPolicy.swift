import Foundation

public enum FirstRunSetupPolicy {
    public static func shouldOpenAccessibilitySettings(
        isGuideDismissed: Bool,
        accessibilityTrusted: Bool
    ) -> Bool {
        !isGuideDismissed && !accessibilityTrusted
    }
}
