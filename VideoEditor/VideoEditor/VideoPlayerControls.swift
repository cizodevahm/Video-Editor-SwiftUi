//
//  VideoPlayerControls.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 09/04/24.
//

import Foundation
import SwiftUI
import AVKit


struct VideoPlayerControlsConfiguration {
    var allowPlaybackSpeedControl: Bool = false
}
protocol oraintationSwitchDelegate{
    func orainTationSwitch(isLandScapOrPortrait: Bool)
    func sideChange(isVideoSideChange: Bool)
}


struct VideoPlayerControls: View {
    
    typealias Configuration = VideoPlayerControlsConfiguration
    var configuration = Configuration()
    
    var player: Binding<AVPlayer?>
    var secondPlayer: Binding<AVPlayer?>
    
    @State private var playerProgress: CGFloat = 0 {
        didSet { syncControlsWithPlayerProgress() }
    }
    
    var delegate: oraintationSwitchDelegate?
    
    @State private var playerTimeObserver: Any? = nil
    @State private var playersPaused = false
    @State private var isLinkUnLink = false
    @State private var changeVideoSide: Bool = false
    @State private var isSwitchView: Bool = false
    
    @State var secondPlayerProgress: Double = 0 { didSet { syncControlsWithPlayerProgress() } }
    @State private var secondPlayerTimeObserver: Any? = nil
    
    var playerCount: Int { secondPlayer.wrappedValue == nil ? 1 : 2 }
    
    @State var firstSliderProgress: CGFloat = 0
    @State var secondSliderProgress: CGFloat = 0
    @State var sliderDragGestureActive = false
    
    @State private var sharedProgress: CGFloat = 0
    @State private var isLinkButtonShow: Bool = false
    
    @State private var totalDuration: Double = 0
    @State private var totalDurationString: String = "--:--"
    
    var body: some View {
        VStack(spacing: isLinkButtonShow == true ? 32 : 0){
            HStack {
                Spacer()
                if isLinkButtonShow{
                    HStack {
                        changeVideoButton
                        switchVideoButton
                        linkVideoButton
                    }
                }
            }
            HStack(spacing: 24) {
                toggleButton
                mainSliders
            }
            .foregroundStyle(.primary)
            .font(.title.weight(.regular))
            .onAppear(perform: setupPlayerObservers)
            .onDisappear(perform: deinitAll)
            .onChange(of: secondPlayer.wrappedValue) { newValue in
                setPlayersPaused()
                seekAllTo(0)
                setupPlayerObservers()
            }
        }
    }
        
    private var toggleButton: some View {
        Button {
            togglePlayer()
        } label: {
            let imageName: String = {
                if playersPaused {
                    return "play.fill"
                } else {
                    return "pause.fill"
                }
            }()
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 27, height: 27)
                .foregroundStyle(.white)
        }
    }
    
    private var linkVideoButton: some View{
        Button {
             toggleLink()
            self.isLinkUnLink.toggle()
        } label: {
            Image(systemName: "link")
                .resizable()
                .scaledToFit()
                .frame(width: 27, height: 27)
                .foregroundStyle(isLinkUnLink ? Color.blue : Color.white)
        }
    }
    
    private var changeVideoButton: some View{
        Button {
            self.changeVideoSide.toggle()
            delegate?.sideChange(isVideoSideChange: self.changeVideoSide)
        } label: {
            Image(systemName: "rectangle.2.swap")
                .resizable()
                .scaledToFit()
                .frame(width: 27, height: 27)
                .foregroundStyle(changeVideoSide ? Color.blue : Color.white)
        }
    }
    
    private var switchVideoButton: some View{
        Button {
            self.isSwitchView.toggle()
            delegate?.orainTationSwitch(isLandScapOrPortrait: self.isSwitchView)
        } label: {
            let imageName: String = {
                if isSwitchView {
                    return "rectangle.landscape.rotate"
                } else {
                    return "rectangle.portrait.rotate"
                }
            }()
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 27, height: 27)
                .foregroundStyle(Color.white)
        }
    }
    
    
    @ViewBuilder
    private var mainSliders: some View {
        HStack(spacing: 48) {
            if let player = player.wrappedValue {
                mainSlider(player: player, progress: isLinkUnLink ? $sharedProgress : $firstSliderProgress)
            }
            if let player = secondPlayer.wrappedValue {
                mainSlider(player: player, progress: isLinkUnLink ?  $sharedProgress : $secondSliderProgress)
            }
        }
    }
    
    @ViewBuilder
    private func mainSlider(player: AVPlayer, progress: Binding<CGFloat>) -> some View {
        let stripeHeight: CGFloat = 4
        let circleSize: CGFloat = 24
        let timeLabelWidth: CGFloat = 10
        GeometryReader { proxy in
            let fullWidth = proxy.size.width
            let progressWidth: CGFloat = fullWidth * progress.wrappedValue
            ZStack {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: stripeHeight/2)
                        .frame(width: max(0, progressWidth), height: stripeHeight)
                        .foregroundStyle(Color.init(red: 52, green: 199, blue: 89))//Resolved(red: 52, green: 199,
                    RoundedRectangle(cornerRadius: stripeHeight/2)
                        .frame(width: max(0, fullWidth - progressWidth), height: stripeHeight)
                        .foregroundStyle(Color.init(red: 51, green: 51, blue: 51))
                }
                Circle()
                    .foregroundStyle(.white)
                    .frame(width: circleSize)
                    .position(x: progressWidth, y: proxy.size.height/2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if isLinkUnLink{
                                    let newProgress = min(
                                        max(0, value.location.x / proxy.size.width),
                                        1.0
                                    )
                                    progress.wrappedValue = newProgress
                                    sharedProgress = newProgress
                                    seekAllTo(Float(newProgress))
                                }else{
                                    progress.wrappedValue = min(
                                        max(
                                            0,
                                            value.location.x
                                        ),
                                        proxy.size.width
                                    ) / proxy.size.width
                                    sharedProgress = progress.wrappedValue
                                    seek(player, to: Float(progress.wrappedValue))
                                }
                            }
                            .onEnded { value in
                                sliderDragGestureActive = false
                            }
                    )
                Text(timeString(from: player.currentItem?.currentTime() ?? CMTime.zero))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .background(Color.black)
                    .cornerRadius(8)
                    .position(x: progressWidth - timeLabelWidth / 2, y: proxy.size.height / 2 - circleSize - 8) // Adjust the Y position as needed
                    .opacity(progressWidth > proxy.size.width - 0 ? 0 : 1)
            }
        }
        .frame(height: circleSize + 20)
    }
    
    private func timeString(from time: CMTime) -> String {
        guard !time.isIndefinite else {
            return "--:--"
        }

        let totalSeconds = CMTimeGetSeconds(time)
        let hours = Int(totalSeconds / 3600)
        let minutes = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func togglePlayer() {
        let newValue = !self.playersPaused
        setPlayersPaused(newValue)
    }
    
    private func toggleLink(){
        let newValue = !self.isLinkUnLink
        setPlayersPaused(false)
    }
    
    private func setPlayersPaused(_ paused: Bool = true) {
        self.playersPaused = paused
        if paused {
            player.wrappedValue?.pause()
            secondPlayer.wrappedValue?.pause()
        } else {
            if firstSliderProgress >= 1 || secondSliderProgress >= 1 {
                if let player = player.wrappedValue {
                    self.seek(player, to: 0)
                }
                if let secondPlayer = secondPlayer.wrappedValue {
                    self.seek(secondPlayer, to: 0)
                }
            }
            player.wrappedValue?.play()
            secondPlayer.wrappedValue?.play()
        }
    }
    
    private func syncControlsWithPlayerProgress() {
        if sliderDragGestureActive { print("Gesture active"); return }
        self.firstSliderProgress = isLinkUnLink == true ? sharedProgress : playerProgress //playerProgress
        self.secondSliderProgress = isLinkUnLink == true ? sharedProgress : secondPlayerProgress//secondPlayerProgress
        if playerProgress >= 1 && (secondPlayerProgress >= 1 || secondPlayer.wrappedValue == nil) { self.playersPaused = true
        }
    }
    
    private func seek(_ player: AVPlayer, to percentage: Float) {
        guard let duration = player.currentItem?.duration else {
            print("No item loaded in the player.")
            return
        }
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekSeconds = totalSeconds * Double(percentage)
        let seekTime = CMTime(seconds: seekSeconds, preferredTimescale: Int32(NSEC_PER_SEC))
        
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter:
                .zero)
        
        if self.isLinkUnLink {
            if let secondPlayer = secondPlayer.wrappedValue {
                secondPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter:
                        .zero)
            }
        }
    }
    
    //Add this function for both slider slide together
    private func seekAllTo(_ percentage: Float) {
        if let player = player.wrappedValue {
            seek(player, to: percentage)
        }
        if let secondPlayer = secondPlayer.wrappedValue {
            seek(secondPlayer, to: percentage)
        }
    }
    
    func setupPlayerObservers() {
        deinitPlayerObservers()
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        if let player = player.wrappedValue {
            self.playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard let duration = player.currentItem?.duration else { return }
                self.playerProgress = time.seconds / duration.seconds
                sharedProgress = time.seconds / duration.seconds
            }
            print("Added #1 observer")
        }
        if let secondPlayer = secondPlayer.wrappedValue {
            self.secondPlayerTimeObserver = secondPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard let duration = secondPlayer.currentItem?.duration else { return }
                self.secondPlayerProgress = time.seconds / duration.seconds
                sharedProgress = time.seconds / duration.seconds
                
            }
            self.isLinkButtonShow = true
            print("Added #2 observer")
        }
    }
    
    func deinitPlayerObservers() {
        if let observer = playerTimeObserver {
            player.wrappedValue?.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        if let observer = secondPlayerTimeObserver {
            secondPlayer.wrappedValue?.removeTimeObserver(observer)
            secondPlayerTimeObserver = nil
        }
    }
    
    func deinitPlayers() {
        player.wrappedValue?.pause()
        player.wrappedValue = nil
        secondPlayer.wrappedValue?.pause()
        secondPlayer.wrappedValue = nil
    }
    
    func deinitAll() {
        deinitPlayerObservers()
        deinitPlayers()
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.white
        VideoPlayerControls(player: .constant(.init()), secondPlayer: .constant(.init()))
            .padding(.vertical, 30)
            .padding(.horizontal)
            .background(Color.black.opacity(0.5))
    }
    .ignoresSafeArea(.container)
    .preferredColorScheme(.dark)
}
