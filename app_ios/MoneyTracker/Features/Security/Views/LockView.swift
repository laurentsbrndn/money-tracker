import SwiftUI

/// The lock screen (APP_FLOWS Flow 12). It covers the whole app: `ScreenShield` puts it in a
/// window above every sheet and dialog.
struct LockView: View {
    let container: AppContainer

    @State private var pin = ""
    @State private var message: String?
    @State private var shake = 0
    @State private var showForgot = false
    @State private var pendingChanges = 0

    private var lock: AppLockController { container.lock }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let wait = PinAttemptPolicy.secondsLeft(until: lock.lockedUntil, now: timeline.date)
            content(waitSeconds: wait)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .task(id: lock.promptToken) { await promptBiometric() }
        .alert("Lupa PIN? Keluar", isPresented: $showForgot) {
            Button("Batal", role: .cancel) {}
            Button("Keluar", role: .destructive) { Task { await logout() } }
        } message: {
            if pendingChanges > 0 {
                Text(
                    "Keluar menghapus data dari perangkat ini dan mematikan kunci PIN. Datamu di server tetap aman dan kembali setelah kamu masuk lagi.\n\nAda \(pendingChanges) perubahan yang belum tersinkron dan akan hilang."
                )
            } else {
                Text(
                    "Keluar menghapus data dari perangkat ini dan mematikan kunci PIN. Datamu di server tetap aman dan kembali setelah kamu masuk lagi."
                )
            }
        }
    }

    private func content(waitSeconds: Int) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(AppColors.seed)
            VStack(spacing: 6) {
                Text("Aplikasi terkunci").font(.title3.bold())
                Text(prompt(waitSeconds: waitSeconds))
                    .font(.subheadline)
                    .foregroundStyle(waitSeconds > 0 || message != nil ? Color.red : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40)
            }
            PinDotsView(filled: pin.count)
                .modifier(ShakeEffect(animatableData: CGFloat(shake)))
            PinPadView(
                onDigit: { append($0) }, onBackspace: { if !pin.isEmpty { pin.removeLast() } },
                isDisabled: waitSeconds > 0)
            HStack(spacing: 24) {
                if lock.biometricEnabled {
                    Button {
                        Task { await promptBiometric(manual: true) }
                    } label: {
                        Label("Gunakan \(lock.biometric.kindName())", systemImage: "faceid")
                    }
                }
                Button("Lupa PIN? Keluar") {
                    Task {
                        pendingChanges =
                            ((try? await container.database.outboxCount()) ?? 0)
                            + container.syncStatus.failedChanges.count
                        showForgot = true
                    }
                }
            }
            .font(.footnote)
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func prompt(waitSeconds: Int) -> String {
        if waitSeconds > 0 {
            let time = Self.format(seconds: waitSeconds)
            return String(localized: "Terlalu banyak percobaan. Coba lagi dalam \(time).")
        }
        return message ?? String(localized: "Masukkan PIN")
    }

    /// "1 mnt 05 dtk" style countdown.
    static func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes == 0 { return String(localized: "\(rest) dtk") }
        return String(localized: "\(minutes) mnt \(String(format: "%02d", rest)) dtk")
    }

    private func append(_ digit: Character) {
        guard pin.count < PinHasher.pinLength else { return }
        message = nil
        pin.append(digit)
        if pin.count == PinHasher.pinLength {
            let entered = pin
            Task { await submit(entered) }
        }
    }

    private func submit(_ entered: String) async {
        let result = await lock.unlock(entered)
        switch result {
        case .success:
            break
        case .wrong:
            message = String(localized: "PIN salah")
            withAnimation(.default) { shake += 1 }
        case .lockedOut:
            message = nil
            withAnimation(.default) { shake += 1 }
        }
        pin = ""
    }

    private func promptBiometric(manual: Bool = false) async {
        // Token 0 is the first appearance: the prompt waits for the scene to become active.
        guard lock.biometricEnabled, lock.locked, lock.promptToken > 0 || manual else { return }
        _ = await lock.unlockWithBiometric(reason: String(localized: "Buka kunci Money Tracker"))
    }

    private func logout() async {
        GoogleSignInCoordinator(clientID: container.config.googleClientID).signOut()
        await container.session.logout()
    }
}

/// A short horizontal shake for a wrong PIN.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 3), y: 0))
    }
}
