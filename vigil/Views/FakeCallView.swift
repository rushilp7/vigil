import SwiftUI

struct FakeCallView: View {
    let onDismiss: () -> Void

    @State private var isCallActive = false
    @State private var callSeconds = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(.systemGray6), Color(.systemGray4)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if isCallActive {
                activeCallView
            } else {
                incomingCallView
            }
        }
    }

    // MARK: - Incoming Call

    private var incomingCallView: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 8) {
                Text("Mom")
                    .font(.largeTitle.bold())
                Text("iPhone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Pulsing phone icon
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.pulse, isActive: true)

            Spacer()

            // Accept / Decline buttons
            HStack(spacing: 60) {
                Button {
                    onDismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .frame(width: 64, height: 64)
                            .background(.red, in: Circle())
                            .foregroundStyle(.white)
                        Text("Decline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    isCallActive = true
                    startTimer()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.title)
                            .frame(width: 64, height: 64)
                            .background(.green, in: Circle())
                            .foregroundStyle(.white)
                        Text("Accept")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Active Call

    private var activeCallView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Mom")
                .font(.largeTitle.bold())
            Text(formattedTime)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                timer?.invalidate()
                onDismiss()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.title)
                    .frame(width: 64, height: 64)
                    .background(.red, in: Circle())
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 60)
        }
    }

    private var formattedTime: String {
        let m = callSeconds / 60
        let s = callSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            callSeconds += 1
        }
    }
}
