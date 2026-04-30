import CoreGraphics

enum ToolbarLayoutPolicy {
    static func shouldUseCompactToolbar(
        width: CGFloat,
        isCurrentlyCompact: Bool,
        animated: Bool
    ) -> Bool {
        guard width > 0 else { return isCurrentlyCompact }

        if animated {
            return isCurrentlyCompact
                ? width < ChromeStyle.toolbarRegularBreakpoint
                : width < ChromeStyle.toolbarCompactBreakpoint
        }

        return width < ChromeStyle.toolbarModeInitialBreakpoint
    }
}
