import SwiftUI

/// Three intro slides (APP_FLOWS Flow 1, step 2); can be skipped.
struct OnboardingView: View {
    let onStart: () -> Void
    let onLogin: () -> Void

    @State private var page = 0

    private struct Slide {
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let slides = [
        Slide(
            symbol: "square.and.pencil", title: "Catat pemasukan & pengeluaran",
            body: "Catat uang masuk dan keluar dalam hitungan detik, bahkan tanpa internet."),
        Slide(
            symbol: "checkmark.circle", title: "Cocokkan dengan saldo asli",
            body: "Bandingkan catatanmu dengan saldo rekening dan dompet, lalu temukan selisihnya."),
        Slide(
            symbol: "chart.pie", title: "Atur needs, wants & savings",
            body:
                "Bagi penghasilan ke kebutuhan, keinginan, dan tabungan, lalu pantau budget tiap bulan."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Lewati", action: onStart).padding()
            }
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: slides[index].symbol)
                            .font(.system(size: 80))
                            .foregroundStyle(AppColors.seed)
                        Text(slides[index].title).font(.title.bold()).multilineTextAlignment(
                            .center)
                        Text(slides[index].body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button(page == slides.count - 1 ? "Mulai" : "Lanjut") {
                    if page == slides.count - 1 {
                        onStart()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Sudah punya akun? Masuk", action: onLogin)
            }
            .padding(20)
        }
    }
}
