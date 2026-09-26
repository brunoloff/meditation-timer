import Flutter
import UIKit
import AVFAudio

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioSessionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "bruno_meditation_timer/audio_session",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    audioSessionChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "activatePlayback" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        // SoLoud deliberately leaves the iOS audio session to the host app.
        // Activate only when playback is requested, not when opening the app.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        result(nil)
      } catch {
        result(FlutterError(code: "audio-session", message: error.localizedDescription, details: nil))
      }
    }
  }
}
