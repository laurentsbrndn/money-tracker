import Foundation
import Observation

/// Set, change, or remove the PIN (`/more/settings/security/pin`). Setting asks for the new PIN
/// twice; changing and removing first check the current one.
@Observable
@MainActor
final class PinSetupViewModel {
    enum Step {
        case current
        case new
        case confirm
    }

    let mode: PinSetupMode
    private(set) var step: Step
    private(set) var pin = ""
    private(set) var message: String?
    private(set) var finished = false
    private(set) var busy = false

    private let lock: AppLockController
    private var firstNew = ""

    init(container: AppContainer, mode: PinSetupMode) {
        self.mode = mode
        self.lock = container.lock
        self.step = mode == .set ? .new : .current
    }

    var lockedUntil: Date? { lock.lockedUntil }

    var title: String {
        switch mode {
        case .set: String(localized: "Atur PIN")
        case .change: String(localized: "Ubah PIN")
        case .remove: String(localized: "Matikan kunci PIN")
        }
    }

    var prompt: String {
        switch step {
        case .current: String(localized: "Masukkan PIN saat ini")
        case .new: String(localized: "Buat PIN 6 digit")
        case .confirm: String(localized: "Ulangi PIN")
        }
    }

    func append(_ digit: Character) {
        guard !busy, pin.count < PinHasher.pinLength else { return }
        message = nil
        pin.append(digit)
        if pin.count == PinHasher.pinLength { Task { await submit() } }
    }

    func backspace() {
        if !pin.isEmpty { pin.removeLast() }
    }

    private func submit() async {
        let entered = pin
        busy = true
        defer { busy = false }
        switch step {
        case .current:
            if mode == .remove {
                report(await lock.removePin(current: entered), onSuccess: { finished = true })
            } else {
                report(await lock.check(entered), onSuccess: { step = .new })
            }
        case .new:
            firstNew = entered
            step = .confirm
        case .confirm:
            if entered == firstNew {
                do {
                    try await lock.setPin(entered)
                    finished = true
                } catch {
                    message = ErrorMessages.describe(error)
                }
            } else {
                message = String(localized: "PIN tidak sama. Ulangi dari awal.")
                firstNew = ""
                step = .new
            }
        }
        pin = ""
    }

    private func report(_ result: PinCheck, onSuccess: () -> Void) {
        switch result {
        case .success: onSuccess()
        case .wrong: message = String(localized: "PIN salah")
        case .lockedOut:
            message = String(localized: "Terlalu banyak percobaan. Coba lagi nanti.")
        }
    }
}
