//
//  FeedViewModel.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 09/04/24.
//

import Foundation
import SwiftUI
import ReplayKit
import Photos

class FeedViewModel: ObservableObject {
    @Published var composerPresented = false
    // MARK: - Screen Capture
    @Published var screenCaptureActive = false
    private var assetWriter: AVAssetWriter? = nil
    private var videoInput: AVAssetWriterInput? = nil
    private var audioMicInput: AVAssetWriterInput? = nil
    private var captureUrl: URL? = nil
}

extension FeedViewModel {
    func toggleRecording() {
        if RPScreenRecorder.shared().isRecording {
            endScreenCapture()
        } else {
            startScreenCapture()
        }
    }
    
    func startScreenCapture() {
        let recorder = RPScreenRecorder.shared()
        recorder.isMicrophoneEnabled = true
        self.captureUrl = .documentsDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        guard let captureUrl else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession error: \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(at: captureUrl)

        do {
            try assetWriter = AVAssetWriter(outputURL: captureUrl, fileType: .mp4)
        } catch {
            print("Could not initialize asset writer: \(error.localizedDescription)")
        }

        let videoSettings: [String : Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: UIScreen.main.bounds.width,
            AVVideoHeightKey: UIScreen.main.bounds.height
        ]
        let audioSettings: [String:Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : 2,
            AVSampleRateKey : 44100.0,
            AVEncoderBitRateKey: 192000
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        audioMicInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        
        guard let assetWriter, let videoInput, let audioMicInput else { return }
        
        videoInput.expectsMediaDataInRealTime = true
        if assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
        }
        
        audioMicInput.expectsMediaDataInRealTime = true
        if assetWriter.canAdd(audioMicInput) {
//            print("Added mic input")
            assetWriter.add(audioMicInput)
        }

        guard recorder.isAvailable else { return }
        self.screenCaptureActive = true
        
        RPScreenRecorder.shared().startCapture { buffer, bufferType, error in
            guard error == nil else { print(error.debugDescription); return }
            if CMSampleBufferDataIsReady(buffer) {
                switch bufferType {
                case .video:
                    if assetWriter.status == AVAssetWriter.Status.unknown {
                        print("Started writing")
                        assetWriter.startWriting()
                        assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
                    }

                    if assetWriter.status == AVAssetWriter.Status.failed {
//                        print("StartCapture Error Occurred, Status = \(assetWriter.status.rawValue), \(assetWriter.error!.localizedDescription) \(assetWriter.error.debugDescription)")
                         return
                    }

                    if assetWriter.status == AVAssetWriter.Status.writing {
                        if videoInput.isReadyForMoreMediaData {
                            if videoInput.append(buffer) == false {
//                                 print("problem writing video")
                            }
                         }
                     }
                case .audioMic:
                    if audioMicInput.isReadyForMoreMediaData {
                        audioMicInput.append(buffer)
                    }
                default:
                    break
                }
            }
        }
    }
    
    func endScreenCapture() {
        RPScreenRecorder.shared().stopCapture { error in
            DispatchQueue.main.async {
                self.screenCaptureActive = false
            }
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard
                let videoInput = self.videoInput,
                let audioMicInput = self.audioMicInput,
                let assetWriter = self.assetWriter,
                let captureUrl = self.captureUrl
            else {
                return
            }

            videoInput.markAsFinished()
            audioMicInput.markAsFinished()
            assetWriter.finishWriting(completionHandler: {

                PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: captureUrl)
                    }) { (saved, error) in

                        if let error = error {
                            print("PHAssetChangeRequest Video Error: \(error.localizedDescription)")
                            return
                        }

                        if saved {
                            // ... show success message
                            print("Saved")
                        }
                    }
                DispatchQueue.main.async {
//                    self.composerIntent = .attachMovie(captureUrl)
//                    self.composerPresented = true
                }
            })
        }
    }
}


