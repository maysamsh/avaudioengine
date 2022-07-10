//
//  ViewController.swift
//  audioEngine
//
//  Created by Maysam Shahsavari on 2022-06-17.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController {
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    
    private let fileName = FileManagerHelper.filename
    
    private let audioEngine = AudioEngine(channels: 1, format: .pcmFormatFloat32, sampleRate: 48000)
    
    private var player: AVAudioPlayer?
    private let pauseNormalImage = UIImage(systemName: "pause.circle")
    private let pauseAlternativeImage = UIImage(systemName: "pause.circle.fill")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        audioEngine.delegate = self
        AudioEngine.setupInputRoute()
        
        infoLabel.text = "Start recording..."
        pauseButton.isEnabled = false
        stopButton.isEnabled = false
        playButton.isEnabled = false
    }
    
    @IBAction func recordAction(_ sender: UIButton) {
        let filePath = FileManagerHelper.getFileURL(for: fileName)
        FileManagerHelper.removeFile(from: filePath)
        
        audioEngine.start()
        recordButton.isEnabled = false
        playButton.isEnabled = false
        pauseButton.isEnabled = true
        stopButton.isEnabled = true
    }
    
    @IBAction func stopAction(_ sender: UIButton) {
        audioEngine.stop()
        pauseButton.isEnabled = false
        recordButton.isEnabled = true
        playButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    @IBAction func pauseAction(_ sender: UIButton) {
        recordButton.isEnabled = false
        playButton.isEnabled = false
        
        if audioEngine.status == .recording {
            audioEngine.pause()
            sender.setImage(self.pauseNormalImage, for: .normal)
        } else if audioEngine.status == .paused {
            audioEngine.resume()
            sender.setImage(self.pauseAlternativeImage, for: .normal)
        }
    }
    
    @IBAction func playAction(_ sender: UIButton) {
        let path = FileManagerHelper.getFileURL(for: fileName)
        self.player = try? AVAudioPlayer(contentsOf: path)
        player?.delegate = self
        self.player?.prepareToPlay()
        self.player?.play()
    }
}

// MARK: - AVAudioPlayer Delegate
extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        pauseButton.isEnabled = false
        stopButton.isEnabled = false
        playButton.isEnabled = false
    }
}

// MARK: - AudioEngine Delegate
extension ViewController: AudioEngineDelegate {
    func audioEngineFailed(error: Error) {
        // Handle Errors here
    }
    
    func audioEngineConverted(data: [Float], time: Float64) {
        // Converts buffer data into float values
    }
    
    func audioEngineStarted() {
        // Triggers once when engine starts returning data
    }
    
    func audioEngineStreaming(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let filePath = FileManagerHelper.getFileURL(for: FileManagerHelper.filename)
        audioEngine.writePCMBuffer(buffer: buffer, output: filePath)
        DispatchQueue.main.async {
            self.infoLabel.text = "\(self.fileSize(fromPath: filePath) ?? "")"
        }
    }
    
    private func fileSize(fromPath url: URL) -> String? {
        let path = url.path
        
        guard let size = try? FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.size],
            let fileSize = size as? UInt64 else {
            return nil
        }

        // bytes
        if fileSize < 1023 {
            return String(format: "%lu bytes", CUnsignedLong(fileSize))
        }
        // KB
        var floatSize = Float(fileSize / 1024)
        if floatSize < 1023 {
            return String(format: "%.1f KB", floatSize)
        }
        // MB
        floatSize = floatSize / 1024
        if floatSize < 1023 {
            return String(format: "%.1f MB", floatSize)
        }
        // GB
        floatSize = floatSize / 1024
        return String(format: "%.1f GB", floatSize)
    }
    
}
