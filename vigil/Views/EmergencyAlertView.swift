import SwiftUI

struct EmergencyAlertView: View {
    let onCancel: () -> Void

    @State private var countdown = 5
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: true)

                Text("EMERGENCY")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Calling 911 in")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))

                Text("\(countdown)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    timer?.invalidate()
                    onCancel()
                } label: {
                    Text("CANCEL")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 1 {
                withAnimation {
                    countdown -= 1
                }
            } else {
                timer?.invalidate()
                call911()
            }
        }
    }

    private func call911() {
        if let url = URL(string: "tel://+18042990185") {
            UIApplication.shared.open(url)
        }
    }
}
