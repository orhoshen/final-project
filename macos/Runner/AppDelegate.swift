import Cocoa
import FlutterMacOS
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
    // private let audioHandler = AudioHandler()
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        // let audioChannel = FlutterMethodChannel(
        //     name: "com.example.final_project/audio",
        //     binaryMessenger: controller.engine.binaryMessenger)
        
        // audioChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        //     guard let self = self else {
        //         result(FlutterError(code: "UNAVAILABLE", message: "AudioHandler not available", details: nil))
        //         return
        //     }
            
        //     switch call.method {
        //     case "playMacOSSound":
        //         // self.audioHandler.playSystemSound()
        //         result(true)
                
        //     case "playPianoNote":
        //         guard let args = call.arguments as? [String: Any],
        //               let noteNumber = args["note"] as? Int else {
        //             result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
        //             return
        //         }
                
        //         // let success = self.audioHandler.playPianoSound(noteNumber: noteNumber)
        //         result(false) // Assuming failure if handler is removed
                
        //     default:
        //         result(FlutterMethodNotImplemented)
        //     }
        // }
        
        super.applicationDidFinishLaunching(notification)
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
