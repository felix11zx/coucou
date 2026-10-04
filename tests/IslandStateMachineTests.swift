import Foundation

@main
@MainActor
enum IslandStateMachineTests {
    static func pause(_ seconds: Double = 0.09) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    static func machine(hover: Bool = true) -> IslandStateMachine {
        let fsm = IslandStateMachine()
        fsm.openOnHover = hover
        fsm.homeToPetitDelay = 0.04
        fsm.hoverCloseDelay = 0.04
        fsm.petitToHiddenDelay = 60
        fsm.greetAutoCollapseDelay = 0.04
        return fsm
    }

    static func main() async throws {
        // Regression: opening on hover invokes the controller's transition callback
        // synchronously, before pollFrame has returned. The callback must already
        // see the cursor inside and must not synthesize a mouse-leave.
        let opening = machine()
        opening.onTransition = { _, to in
            if to == .home && !opening.isMouseInside { opening.mouseLeft() }
        }
        opening.mouseEntered()
        try await pause(0.2)
        precondition(opening.state == .home, "Hover-open must survive the close grace period")
        opening.mouseLeft()
        try await pause()
        precondition(opening.state == .petit, "Leaving must still close the hovered island")
        opening.onTransition = nil
        opening.cancelTimers()

        // A greeting starts with a pending completion timer, then the cursor enters.
        let interruptedGreeting = machine()
        interruptedGreeting.launch()
        interruptedGreeting.greetComplete()
        interruptedGreeting.mouseEntered()
        try await pause()
        precondition(interruptedGreeting.state == .coucou,
                     "A queued greeting timer must not close underneath the cursor")
        interruptedGreeting.greetComplete()
        precondition(interruptedGreeting.state == .home)
        try await pause()
        precondition(interruptedGreeting.state == .home)
        interruptedGreeting.mouseLeft()
        try await pause()
        precondition(interruptedGreeting.state == .petit)
        interruptedGreeting.cancelTimers()

        // Disabled hover preserves compact-on-hover and click-to-open.
        let legacy = machine(hover: false)
        legacy.mouseEntered()
        precondition(legacy.state == .petit)
        legacy.click()
        precondition(legacy.state == .home)
        legacy.mouseLeft()
        try await pause()
        precondition(legacy.state == .petit)

        // Hover opens both hidden and compact islands; leaving closes promptly.
        let hover = machine()
        hover.mouseEntered()
        precondition(hover.state == .home)
        hover.mouseLeft()
        try await pause()
        precondition(hover.state == .petit)
        hover.mouseEntered()
        precondition(hover.state == .home)

        // Returning during the grace period cancels the pending close.
        hover.mouseLeft()
        try await pause(0.01)
        hover.mouseEntered()
        try await pause()
        precondition(hover.state == .home)
        hover.cancelTimers()

        // A user pin or agent request suppresses automatic closing.
        var heldOpen = true
        let pinned = machine()
        pinned.isHeldOpen = { heldOpen }
        pinned.mouseEntered()
        pinned.mouseLeft()
        try await pause()
        precondition(pinned.state == .home)

        // Explicit dismissal (outside click) must override a pin.
        pinned.collapse()
        precondition(pinned.state == .petit)
        try await pause()
        precondition(pinned.state == .petit)
        pinned.mouseEntered()
        precondition(pinned.state == .home)
        heldOpen = false
        pinned.mouseLeft()
        try await pause()
        precondition(pinned.state == .petit)

        // Enabling a pin while a close is queued must also prevent that close.
        let queued = machine()
        queued.isHeldOpen = { heldOpen }
        queued.mouseEntered()
        queued.mouseLeft()
        heldOpen = true
        try await pause()
        precondition(queued.state == .home)
        queued.cancelTimers()

        // Keep-expanded converts the completed greeting to the normal view.
        let greeting = machine()
        greeting.isHeldOpen = { true }
        greeting.launch()
        greeting.greetComplete()
        precondition(greeting.state == .home)

        let greetingHover = machine()
        greetingHover.launch()
        greetingHover.mouseEntered()
        greetingHover.greetComplete()
        precondition(greetingHover.state == .home)
        greetingHover.cancelTimers()

        // Without hover or a pin the normal launch greeting still collapses.
        let normalGreeting = machine(hover: false)
        normalGreeting.launch()
        normalGreeting.greetComplete()
        try await pause()
        precondition(normalGreeting.state == .petit)

        // An external alert replaces a greeting; its old timer cannot close it.
        let alert = machine()
        alert.launch()
        alert.greetComplete()
        alert.openedExternally()
        try await pause()
        precondition(alert.state == .home)
        alert.collapse()
        precondition(alert.state == .petit)

        print("Island hover, pin, outside-dismissal and greeting regressions: all passed")
    }
}
