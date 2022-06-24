//
//  AudioEngine.swift
//  star
//
//  Created by Maysam Shahsavari on 2022-06-20.
//

import Foundation
import AVFoundation
import CoreAudio

protocol AudioEngineDelegate: NSObjectProtocol {
    func audioEngineFailed(error: Error)
    func audioEngineConverted(data: [Float], time: Float64)
    func audioEngineStreaming(buffer: AVAudioPCMBuffer, time: AVAudioTime)
    func audioEngineStarted()
}

extension AudioEngineDelegate {
    func audioEngineStreaming(buffer: AVAudioPCMBuffer, time: AVAudioTime) {}
}

final class AudioEngine {
    enum AudioEngineError: Error, LocalizedError {
        case noInputChannel
        case engineIsNotInitialized
        case invalidFormat
        case failedToCreateConverter
    }
    
    weak var delegate: AudioEngineDelegate?
    
    private var engine = AVAudioEngine()
    private var streamingData: Bool = false
    private var numberOfChannels: UInt32
    private var converterFormat: AVAudioCommonFormat
    private var sampleRate: Double
    private var outputFile: AVAudioFile?
    private let inputBus: AVAudioNodeBus = 0
    private let outputBus: AVAudioNodeBus = 0
    private let bufferSize: AVAudioFrameCount = 1024
    private var inputFormat: AVAudioFormat!

    private (set) var status: EngineStatus = .notInitialized
    
    enum EngineStatus {
        case notInitialized
        case ready
        case recording
        case paused
        case failed
    }
    
    init(channels: Int, format: AVAudioCommonFormat, sampleRate: Double) {
        numberOfChannels = UInt32(channels)
        converterFormat = format
        self.sampleRate = sampleRate
        
        setupEngine()
    }
    
    fileprivate func setupEngine() {
        /// I don't know what the F is happening under the hood, but if you don't call these next few lines in one closure your code will crash.
        /// Maybe it's threading issue?
        self.engine.reset()
        let inputNode = engine.inputNode
        inputFormat = inputNode.outputFormat(forBus: outputBus)
        inputNode.installTap(onBus: inputBus, bufferSize: bufferSize, format: inputFormat, block: { [weak self] (buffer, time) in
            self?.convert(buffer: buffer, time: time.audioTimeStamp.mSampleTime)
        })
        engine.prepare()
        self.status = .ready
    }
    
    func start()  {
        guard (engine.inputNode.inputFormat(forBus: inputBus).channelCount > 0) else {
            print("[AudioEngine]: No input is available.")
            self.streamingData = false
            self.delegate?.audioEngineFailed(error: AudioEngineError.noInputChannel)
            self.status = .failed
            return
        }
        
        do {
            try engine.start()
            self.status = .recording
        } catch {
            self.streamingData = false
            self.delegate?.audioEngineFailed(error: error)
            print("[AudioEngine]: \(error.localizedDescription)")
            return
        }
        
        print("[AudioEngine]: Started tapping microphone.")
        return
    }
    
    func pause() {
        self.engine.pause()
        self.status = .paused
        self.streamingData = false
    }
    
    func resume() {
        do {
            try engine.start()
            self.status = .recording
        } catch {
            self.status = .failed
            self.streamingData = true
            self.delegate?.audioEngineFailed(error: error)
            print("[AudioEngine]: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        self.engine.stop()
        self.outputFile = nil
        self.engine.reset()
        self.engine.inputNode.removeTap(onBus: inputBus)
    }
    
    func writePCMBuffer(buffer: AVAudioPCMBuffer, output: URL) {
        let settings: [String: Any] = [
            AVFormatIDKey: buffer.format.settings[AVFormatIDKey] ?? kAudioFormatLinearPCM,
            AVNumberOfChannelsKey: buffer.format.settings[AVNumberOfChannelsKey] ?? 1,
            AVSampleRateKey: buffer.format.settings[AVSampleRateKey] ?? sampleRate,
            AVLinearPCMBitDepthKey: buffer.format.settings[AVLinearPCMBitDepthKey] ?? 16
        ]
        
        do {
            if outputFile == nil {
                outputFile = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
                print("[AudioEngine]: Audio file created.")
            }
            try outputFile?.write(from: buffer)
            print("[AudioEngine] Writing buffer into the file...")
        } catch {
            print("[AudioEngine]: Failed to write into the file.")
        }
    }
    
    /**
     This method sets the right route in regards to input and output source for audio, otherwise the OS will pick the builtin microphone.
     */
    static func setupInputRoute() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP, .allowBluetooth])
        let currentRoute = audioSession.currentRoute
        if currentRoute.outputs.count != 0 {
            for description in currentRoute.outputs {
                if description.portType == AVAudioSession.Port.headphones || description.portType == AVAudioSession.Port.bluetoothA2DP {
                    try? audioSession.overrideOutputAudioPort(.none)
                } else {
                    try? audioSession.overrideOutputAudioPort(.speaker)
                }
            }
        } else {
            try? audioSession.overrideOutputAudioPort(.speaker)
        }
        
        if let availableInputs = audioSession.availableInputs {
            var mic : AVAudioSessionPortDescription? = nil
            
            for input in availableInputs {
                if input.portType == .headphones || input.portType == .bluetoothHFP {
                    print("[AudioEngine]: \(input.portName) (\(input.portType.rawValue)) is selected as the input source. ")
                    mic = input
                    break
                }
            }
            
            if let mic = mic {
                try? audioSession.setPreferredInput(mic)
            }
        }
        
        try? audioSession.setActive(true)
        print("[AudioEngine]: Audio session is active.")
    }
    
    private func convert(buffer: AVAudioPCMBuffer, time: Float64) {
        guard let outputFormat = AVAudioFormat(commonFormat: self.converterFormat, sampleRate: sampleRate, channels: numberOfChannels, interleaved: false) else {
            streamingData = false
            delegate?.audioEngineFailed(error: AudioEngineError.invalidFormat)
            print("[AudioEngine]: Failed to create output format.")
            self.status = .failed
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            streamingData = false
            delegate?.audioEngineFailed(error: AudioEngineError.failedToCreateConverter)
            print("[AudioEngine]: Failed to create the converter.")
            self.status = .failed
            return
        }
        
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return buffer
        }
        
        let targetFrameCapacity = AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)
        if let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: targetFrameCapacity) {
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            switch status {
            case .haveData:
                self.delegate?.audioEngineStreaming(buffer: buffer, time: AVAudioTime.init())
                let arraySize = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: convertedBuffer.floatChannelData![0], count: arraySize))
                if self.streamingData == false {
                    streamingData = true
                    delegate?.audioEngineStarted()
                }
                delegate?.audioEngineConverted(data: samples, time: time)
            case .error:
                if let error = error {
                    streamingData = false
                    delegate?.audioEngineFailed(error: error)
                }
                self.status = .failed
                print("[AudioEngine]: Converter failed, \(error?.localizedDescription ?? "Unknown error")")
            case .endOfStream:
                streamingData = false
                print("[AudioEngine]: The end of stream has been reached. No data was returned.")
            case .inputRanDry:
                streamingData = false
                print("[AudioEngine]: Converter input ran dry.")
            @unknown default:
                if let error = error {
                    streamingData = false
                    delegate?.audioEngineFailed(error: error)
                }
                print("[AudioEngine]: Unknown converter error")
            }
            
        }
        
    }
    
}
