import SwiftUI

struct MonthSelector: View {
    let month: YearMonth
    let canGoNext: Bool
    let isLocked: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) { Image(systemName: "chevron.left") }
                .accessibilityLabel("Bulan sebelumnya")
            Spacer()
            HStack(spacing: 6) {
                Text(month.titleText).font(.headline)
                if isLocked {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .disabled(!canGoNext)
                .accessibilityLabel("Bulan berikutnya")
        }
        .padding(.horizontal, 4)
    }
}
