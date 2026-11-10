import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannels: [FlutterMethodChannel] = []
  private let documents = ServiceMetDocuments()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let permissions = FlutterMethodChannel(name: "bo.metrica.smet/permisos", binaryMessenger: messenger)
    permissions.setMethodCallHandler { call, result in
      guard call.method == "camaraConcedida" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
    }

    let screen = FlutterMethodChannel(name: "bo.metrica.smet/pantalla", binaryMessenger: messenger)
    screen.setMethodCallHandler { call, result in
      guard call.method == "mantenerEncendida",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["encendida"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.isIdleTimerDisabled = enabled
      result(nil)
    }

    let files = FlutterMethodChannel(name: "bo.metrica.smet/saf", binaryMessenger: messenger)
    files.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "La app se está cerrando.", details: nil))
        return
      }
      self.documents.handle(call, result: result)
    }
    platformChannels = [permissions, screen, files]
  }
}
