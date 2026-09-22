import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var tonePlayer: AVAudioPlayer?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "brain_rush/sound_effects",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "play" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.playTone(call.arguments as? String ?? "tap")
      result(nil)
    }
  }

  private func playTone(_ cue: String) {
    let frequency: Double
    let seconds: Double
    switch cue {
    case "incorrect": (frequency, seconds) = (220, 0.12)
    case "timeUp": (frequency, seconds) = (190, 0.18)
    case "fast": (frequency, seconds) = (780, 0.08)
    case "streak": (frequency, seconds) = (660, 0.15)
    case "achievement": (frequency, seconds) = (880, 0.19)
    case "levelUp": (frequency, seconds) = (980, 0.19)
    case "countdown": (frequency, seconds) = (480, 0.055)
    case "correct": (frequency, seconds) = (590, 0.08)
    default: (frequency, seconds) = (420, 0.055)
    }
    let rate = 22050
    let count = Int(Double(rate) * seconds)
    var data = Data()
    func append16(_ value: UInt16) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    func append32(_ value: UInt32) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    data.append(contentsOf: Array("RIFF".utf8))
    append32(UInt32(36 + count * 2))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append32(16)
    append16(1)
    append16(1)
    append32(UInt32(rate))
    append32(UInt32(rate * 2))
    append16(2)
    append16(16)
    data.append(contentsOf: Array("data".utf8))
    append32(UInt32(count * 2))
    for i in 0..<count {
      let t = Double(i) / Double(rate)
      let attack = min(1.0, Double(i) / 220.0)
      let release = min(1.0, Double(count - i) / 1100.0)
      let amplitude = sin(2 * .pi * frequency * t) * min(attack, release) * 0.11
      append16(UInt16(bitPattern: Int16(amplitude * 32767)))
    }
    tonePlayer?.stop()
    tonePlayer = try? AVAudioPlayer(data: data)
    tonePlayer?.prepareToPlay()
    tonePlayer?.play()
  }
}
