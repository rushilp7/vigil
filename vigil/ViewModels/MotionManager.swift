import Foundation
import CoreMotion
import Observation

@Observable
class MotionManager {
    var isShakeDetected = false
    var isMonitoring = false

    @ObservationIgnored
    private let motionManager = CMMotionManager()

    /// Tracks recent acceleration spikes for shake detection
    @ObservationIgnored
    private var recentSpikes: [Date] = []

    /// Number of direction reversals needed within the time window
    private let requiredSpikes = 3
    /// Time window in seconds
    private let spikeWindow: TimeInterval = 1.0
    /// Acceleration magnitude threshold (in g's)
    private let magnitudeThreshold: Double = 2.0

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available (simulator?)")
            return
        }

        isMonitoring = true
        isShakeDetected = false
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            self.handleMotion(motion)
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        recentSpikes = []
    }

    func resetShakeDetection() {
        isShakeDetected = false
        recentSpikes = []
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
        let accel = motion.userAcceleration
        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)

        if magnitude > magnitudeThreshold {
            let now = Date()
            recentSpikes.append(now)

            // Remove spikes outside the time window
            recentSpikes = recentSpikes.filter { now.timeIntervalSince($0) <= spikeWindow }

            if recentSpikes.count >= requiredSpikes {
                isShakeDetected = true
                recentSpikes = []
            }
        }
    }
}
