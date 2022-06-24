//
//  ViewController.swift
//  audioEngine
//
//  Created by Maysam Shahsavari on 2022-06-17.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController {
    private let audioEngine = AudioEngine(channels: 1, format: .pcmFormatFloat32, sampleRate: 48000)
    
    private var player: AVAudioPlayer?
    private let pauseNormalImage = UIImage(systemName: "pause.circle")
    private let pauseAlternativeImage = UIImage(systemName: "pause.circle.fill")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        audioEngine.delegate = self
        AudioEngine.setupInputRoute()
    }
    
    @IBAction func startAction(_ sender: UIButton) {
        audioEngine.start()
    }
    
    @IBAction func stopAction(_ sender: UIButton) {
        audioEngine.stop()
    }
    
    @IBAction func pauseAction(_ sender: UIButton) {
        if audioEngine.status == .recording {
            audioEngine.pause()
            sender.setImage(self.pauseNormalImage, for: .normal)
        } else if audioEngine.status == .paused {
            audioEngine.resume()
            sender.setImage(self.pauseAlternativeImage, for: .normal)
        }
    }
    
    @IBAction func playAction(_ sender: UIButton) {
        let path = FileManagerHelper.getFileURL(for: FileManagerHelper.filename)
        self.player = try? AVAudioPlayer(contentsOf: path)
        self.player?.prepareToPlay()
        self.player?.play()
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
    }
}
