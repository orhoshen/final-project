import Foundation
import AVFoundation

class AudioHandler: NSObject {
    private var audioPlayer: AVAudioPlayer?
    
    @objc func playSystemSound() -> Bool {
        NSLog("AudioHandler: Attempting to play system sound")
        
        // Try to play a system sound first
        let systemSoundID: SystemSoundID = 1104 // Standard system sound
        AudioServicesPlaySystemSound(systemSoundID)
        
        return true
    }
    
    @objc func playPianoSound(note: Int) -> Bool {
        NSLog("AudioHandler: Attempting to play piano sound for note \(note)")
        
        guard let soundURL = Bundle.main.url(forResource: "note_\(note)", withExtension: "mp3", subdirectory: "flutter_assets/assets/piano_notes") else {
            NSLog("AudioHandler: Could not find sound file for note \(note)")
            return false
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            
            NSLog("AudioHandler: Successfully started playing note \(note)")
            return true
        } catch {
            NSLog("AudioHandler: Error playing sound: \(error.localizedDescription)")
            return false
        }
    }
} 