import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var soundPlayer: AVAudioPlayer?
  private var sessionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.openinfra.boxBreathingApp/session", binaryMessenger: controller.binaryMessenger)
    sessionChannel = channel
    NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted), name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "keepAwake":
        UIApplication.shared.isIdleTimerDisabled = call.arguments as? Bool ?? false
        result(nil)
      case "playSound":
        guard let data = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(code: "invalidAudio", message: "Missing sound data", details: nil)); return
        }
        do {
          let audio = AVAudioSession.sharedInstance()
          // Media playback avoids the keyboard-click/silent-switch path. Mixing preserves other audio.
          try audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
          try audio.setActive(true)
          self.soundPlayer?.stop()
          self.soundPlayer = try AVAudioPlayer(data: data.data)
          self.soundPlayer?.volume = 0.7
          guard self.soundPlayer?.play() == true else {
            result(FlutterError(code: "playFailed", message: "Audio playback did not start", details: nil)); return
          }
          result(nil)
        } catch {
          result(FlutterError(code: "audioUnavailable", message: "Audio playback is unavailable", details: nil))
        }
      #if DEBUG
      case "debugAudioEvent":
        let routeLoss = call.arguments as? String == "routeLoss"
        DispatchQueue.global(qos: .userInitiated).async {
          if routeLoss {
            NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
              userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
          } else {
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
              userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
          }
        }
        result(nil)
      #endif
      case "stopSound":
        self.stopSound()
        result(nil)
      case "info":
        let preferences = UserDefaults.standard
        let audio = AVAudioSession.sharedInstance()
        result([
          "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
          "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
          "soundEnabled": preferences.object(forKey: "soundEnabled") as? Bool ?? true,
          "hapticsEnabled": preferences.object(forKey: "hapticsEnabled") as? Bool ?? true,
          "audioRoute": audio.currentRoute.outputs.map { $0.portType.rawValue },
          "outputVolume": audio.outputVolume,
          "audioCategory": audio.category.rawValue,
          "soundPlaying": self.soundPlayer?.isPlaying ?? false,
          "idleTimerDisabled": UIApplication.shared.isIdleTimerDisabled
        ])
      case "savePreferences":
        guard let preferences = call.arguments as? [String: Bool] else {
          result(FlutterError(code: "invalidPreferences", message: "Invalid preferences", details: nil)); return
        }
        for key in ["soundEnabled", "hapticsEnabled"] {
          if let value = preferences[key] { UserDefaults.standard.set(value, forKey: key) }
        }
        result(nil)
      case "openURL":
        guard let value = call.arguments as? String, let url = URL(string: value),
              url.scheme == "https", url.host == "github.com" else {
          result(FlutterError(code: "invalidURL", message: "Unsupported link", details: nil)); return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success ? nil : FlutterError(code: "openFailed", message: "Could not open link", details: nil))
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func stopSound() {
    soundPlayer?.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  @objc private func audioInterrupted(_ notification: Notification) {
    guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          type == AVAudioSession.InterruptionType.began.rawValue else { return }
    DispatchQueue.main.async { [weak self] in
      self?.stopSound()
      self?.sessionChannel?.invokeMethod("audioInterrupted", arguments: nil)
    }
  }

  @objc private func routeChanged(_ notification: Notification) {
    guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
    DispatchQueue.main.async { [weak self] in
      self?.stopSound()
      self?.sessionChannel?.invokeMethod("audioInterrupted", arguments: nil)
    }
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    application.isIdleTimerDisabled = false
    stopSound()
    super.applicationDidEnterBackground(application)
  }
}
