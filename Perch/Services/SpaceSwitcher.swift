import Cocoa

final class SpaceSwitcher {
    func switchToDesktop(_ number: Int) {
        guard (1...9).contains(number) else { return }
        guard let keyCode = keyCode(for: number) else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = .maskControl
        keyUp?.flags = .maskControl

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func keyCode(for number: Int) -> CGKeyCode? {
        switch number {
        case 1: return 18
        case 2: return 19
        case 3: return 20
        case 4: return 21
        case 5: return 23
        case 6: return 22
        case 7: return 26
        case 8: return 28
        case 9: return 25
        default: return nil
        }
    }
}
