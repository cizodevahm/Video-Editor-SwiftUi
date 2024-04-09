//
//  ScreenCaptureButton.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 09/04/24.
//

import Foundation
import SwiftUI

struct ScreenCaptureButton: View {
    enum _State {
        case idle
        case recording
    }
    
    @Binding var recordingActive: Bool
    var toggleRecording: () -> ()
    
    var state: _State {
        return recordingActive ? .recording : .idle
    }
    
    var body: some View {
        switch state {
        case .idle:
            startRecordingButton
        case .recording:
            endRecordingButton
        }
    }
    
    @ViewBuilder
    var startRecordingButton: some View {
        Button {
            toggleRecording()
        } label: {
            Image(systemName: "mic.fill")
                .font(.title)
        }
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    var endRecordingButton: some View {
        let circleSize: CGFloat = 25
        let squareSize: CGFloat = 10
        Button {
            toggleRecording()
        } label: {
            ZStack(alignment: .center) {
                Circle()
                    .foregroundColor(.red)
                Image(systemName: "square.fill")
                    .resizable()
                    .frame(width: squareSize, height: squareSize)
                    .foregroundColor(.white)
            }
            .frame(width: circleSize, height: circleSize)
        }
    }
}

#Preview {
    ScreenCaptureButton(recordingActive: .constant(false), toggleRecording: {})
}
