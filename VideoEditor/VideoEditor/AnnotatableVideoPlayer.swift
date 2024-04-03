//
//  AnnotatableVideoPlayer.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 03/04/24.
//

import SwiftUI
import Foundation
import AVKit

struct AnnotatableVideoPlayer: View {
    
    let url: URL
    var strokeWidth: CGFloat = 3

//    @ObservedObject var feedViewModel: FeedViewModel
//    var completion: () -> ()

    @State var player: AVPlayer? = nil
    @State var playerProgress: Double = 0 { didSet { syncControlsWithPlayerProgress() } }
    @State var playerPaused = false
    @State var inferredSliderWidth: CGFloat? = nil
    
    @State private var startPoint: CGPoint = CGPoint(x: 196.5, y: 426.0)
    @State private var endPoint1: CGPoint =  CGPoint(x: 246.5, y: 276)
    @State private var endPoint2: CGPoint =  CGPoint(x: 121.5, y: 276)
    
    @State private var isDrawingAngleVisible: Bool = false
    
    
    @State var angleShow: Bool = false
    @State var isAngleAdded: Bool = false
    @State var sliderDragGestureActive = false {
        didSet {
            if sliderDragGestureActive {
                if !playerPaused {
                    togglePlayer()
                    playerPausedBecauseOfDragGesture = true
                }
            } else {
                if playerPausedBecauseOfDragGesture {
                    togglePlayer()
                    playerPaused = false
                }
                playerPausedBecauseOfDragGesture = false
            }
        }
    }
    @State var playerPausedBecauseOfDragGesture = false
    @State var playerSliderLocation: CGPoint = .zero
    @State private var playerTimeObserver: Any? = nil

    @State var inputMode: InputMode = .ui

    @State var canvasAdditions = [CanvasAddition]()

    @State var scribbleEnded: Bool = true
    @State var currentScribble = Scribble(color: .blue)
    @State var currentLine: Line? = nil
    @State var currentAngle: AngleView? = nil
    @State var currentArrow: Arrow? = nil

    @State var drawColor: Color = .blue {
        didSet {
            currentScribble.color = drawColor
        }
    }
    
    var canvasActive: Bool {
        inputMode != .ui
    }

    var lines: [Line] {
        var result = [Line]()
        self.canvasAdditions.forEach { addition in
            switch addition {
            case .line(let line):
                result.append(line)
            default:
                break
            }
        }
        return result
    }

    var arrows: [Arrow] {
        var result = [Arrow]()
        self.canvasAdditions.forEach { addition in
            switch addition {
            case .arrow(let arrow):
                result.append(arrow)
            default:
                break
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 25) {
                header
                    .padding(.horizontal)
                mainLayer
                footer
                    .padding(.horizontal, 36)
            }
        }
        .onAppear(perform: setupObserver)
        .onDisappear(perform: deinitPlayerAndObserver)
    }

    var header: some View {
        HStack {
            dismissButton
            Spacer()
//            screenCaptureButton
        }
    }

    var mainLayer: some View {
        ZStack {
            ZoomableScrollView {
                ZStack {
                    playerLayer
                    canvasLayer
                    if angleShow{
                        drawingAngle
                    }
                }
            }
            .onAppear {
                loadPlayer()
            }
            inputLayer
        }
    }

    var footer: some View {
        playerControls
    }

    var playerLayer: some View {
        VideoPlayer(player: player)
            .disabled(true)
    }
    
    @ViewBuilder
    var playerControls: some View {
        HStack(spacing: 14) {
            playPauseButton
            playerSlider
//            playerCountdown
        }
    }

    @ViewBuilder
    var playPauseButton: some View {
        Button {
            self.togglePlayer()
        } label: {
            let imageName: String = {
                if playerPaused {
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

    @ViewBuilder
    var playerSlider: some View {
        let height: CGFloat = 8
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: height/2)
                    .frame(height: height)
                    .foregroundStyle(.white.opacity(0.33))
                RoundedRectangle(cornerRadius: height/2)
                    .frame(
                        width: abs(playerSliderLocation.x),
                        height: height
                    )
                    .position(
                        x: abs(playerSliderLocation.x)/2,
                        y: height/2
                    )
                    .foregroundStyle(.white)
            }
            .foregroundStyle(.white)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        sliderDragGestureActive = true
                        playerSliderLocation.x = min(
                            max(
                                0,
                                value.location.x
                            ),
                            proxy.size.width
                        )
                        let progress = Float(playerSliderLocation.x/proxy.size.width)
                        seekPlayerToPercentage(progress)
                        playerSliderLocation.y = height/2
                    }
                    .onEnded { value in
                        sliderDragGestureActive = false
                    }
            )
            .onAppear {
                self.inferredSliderWidth = proxy.size.width
            }
        }
        .frame(height: height)
        .onAppear {
            playerSliderLocation.y = height/2
        }
    }

//    var playerCountdown: some View {
//        VideoPlayerCountdown(player: $player)
//            .foregroundStyle(.white.opacity(0.75))
//    }

    func loadPlayer(autoplay: Bool = true) {
        self.player = .init(url: url)
        if autoplay {
            self.player?.play()
        }
    }

    func togglePlayer() {
        let newValue = !self.playerPaused
        setPlayerPaused(newValue)
    }

    func setPlayerPaused(_ paused: Bool = true) {
        guard let player else { return }
        self.playerPaused = paused
        if paused {
            player.pause()
        } else {
            if playerProgress >= 1 { self.seekPlayerToPercentage(0) }
            player.play()
        }
    }

    func syncControlsWithPlayerProgress() {
        if sliderDragGestureActive { print("Gesture active"); return }
        guard let inferredSliderWidth else { return }
        self.playerSliderLocation.x = playerProgress*inferredSliderWidth
        if playerProgress >= 1 { self.playerPaused = true }
    }

    func seekPlayerToPercentage(_ percentage: Float) {
//        guard let player else { return }
//        guard let duration = player.currentItem?.duration else {
//            print("No item loaded in the player.")
//            return
//        }
//
//        let totalSeconds = CMTimeGetSeconds(duration)
//        let seekSeconds = totalSeconds * Double(percentage)
//        let seekTime = CMTime(seconds: seekSeconds, preferredTimescale: Int32(NSEC_PER_SEC))
//
//        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

extension AnnotatableVideoPlayer {
    enum InputMode: CaseIterable {
        case ui
        case scribble
        case line
        case Angle
        case arrow

        var systemImageName: String {
            switch self {
            case .ui: "hand.tap.fill"
            case .scribble: "scribble.variable"
            case .Angle : "checkmark"
            case .line: "line.diagonal"
            case .arrow: "line.diagonal.arrow"
            }
        }
    }

    enum CanvasAddition {
        case scribble([Scribble])
        case line(Line)
        case Angle(AngleView)
        case arrow(Arrow)
    }

    @ViewBuilder
    var canvasLayer: some View {
        GeometryReader { geometry in
            canvas()
                .gesture(
                    DragGesture(
                        minimumDistance: 0,
                        coordinateSpace: .local
                    )
                    .onChanged { value in
                        if inputMode == .scribble {
                            if scribbleEnded {
                                scribbleEnded = false
                                self.currentScribble.color = drawColor
                                self.canvasAdditions.append(.scribble([]))
                            }
                            let newPoint = value.location
                            currentScribble.points.append(newPoint)
                            let lastIndex = self.canvasAdditions.count - 1
                            if lastIndex >= 0 {
                                switch canvasAdditions[lastIndex] {
                                case .scribble(var scribbles):
                                    scribbles.append(currentScribble)
                                    canvasAdditions[lastIndex] = .scribble(scribbles)
                                default:
                                    break
                                }
                            }
                        } else if inputMode == .line {
                            if currentLine == nil {
                                currentLine = Line(start: value.startLocation, end: value.location, color: drawColor)
                            } else {
                                currentLine?.end = value.location
                            }
                        }else if inputMode == .Angle {
                            if currentAngle == nil {
//                                angleShow = true
                                DispatchQueue.main.async {
                                    handleDrag(value: value)
                                }
                            } else {
                                //currentAngle?.end = value.location
                            }
                        } else if inputMode == .arrow {
                            var startLocation = value.startLocation
                            startLocation.y += 1
                            if currentArrow == nil {
                                currentArrow = .init(
                                    start: startLocation,
                                    end: value.location,
                                    color: drawColor
                                )
                            } else {
                                currentArrow?.end = value.location
                            }
                        }
                    }
                        .onEnded { value in
                            if inputMode == .line {
                                if let line = currentLine {
                                    canvasAdditions.append(.line(line))
                                }
                                currentLine = nil
                            } else if inputMode == .Angle {
                                if self.isAngleAdded == false{
                                    if let line = currentAngle {
                                        self.isAngleAdded = true
                                        canvasAdditions.append(.Angle(line))
                                    }
                                    currentAngle = nil
                                }
                            }
                            else if inputMode == .scribble {
                                scribbleEnded = true
                                currentScribble = newScribble()
                            } else if inputMode == .arrow {
                                if let arrow = currentArrow {
                                    canvasAdditions.append(.arrow(arrow))
                                }
                                currentArrow = nil
                            }
                        }
                )
                .allowsHitTesting(canvasActive)
                .onAppear {
                    currentScribble = newScribble()
                    startPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
        }
}

    func canvas() -> some View {
        ZStack {
            Canvas { context, size in
                for addition in canvasAdditions {
                    switch addition {
                    case .scribble(let scribbles):
                        for scribble in scribbles {
                            var path = Path()
                            path.addLines(scribble.points)
                            context.stroke(
                                path,
                                with: .color(scribble.color),
                                lineWidth: scribble.lineWidth
                            )
                        }
                    case .line(let line):
                        context.stroke(
                            line.path,
                            with: .color(line.color),
                            lineWidth: strokeWidth
                        )
                    case .arrow(let arrow):
                        context.stroke(
                            arrow.path,
                            with: .color(arrow.color),
                            style: .init(
                                lineWidth: strokeWidth,
                                lineJoin: .round
                            )
                        )
                    case .Angle(let angle):
//                        context.stroke(
//                            angle.bo.path,
//                            with: .color(angle.color),
//                            lineWidth: strokeWidth
//                        )
                        ""
                    }
                }
                if let currentLine {
                    context.stroke(
                        currentLine.path,
                        with: .color(drawColor),
                        lineWidth: strokeWidth
                    )
                }
                //For Angle Code
                if let currentAngle {
//                    context.stroke(
//                        currentAngle.path,
//                        with: .color(drawColor),
//                        lineWidth: strokeWidth
//                    )
                }

                if let currentArrow {
                    context.stroke(
                        currentArrow.path,
                        with: .color(currentArrow.color),
                        lineWidth: strokeWidth
                    )
                }
            }
        }
    }

    func newScribble() -> Scribble {
        Scribble(color: drawColor, lineWidth: strokeWidth)
    }

    func removeLastCanvasAddition() {
        let lastIndex = self.canvasAdditions.count - 1
//        if lastIndex == 0 {
//            self.isAngleAdded = false
//            angleShow = false
//        }
        if lastIndex >= 0 {
            let lastAddition = self.canvasAdditions.removeLast()
        }
    }

    func clearCanvas() {
        self.currentScribble = newScribble()
        self.canvasAdditions = []
    }
}

extension AnnotatableVideoPlayer {
    @ViewBuilder
    var inputLayer: some View {
        ZStack {
            drawingModesLayer
        }
    }

    var dismissButton: some View {
        Button {
        } label: {
            Image(systemName: "xmark")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }

    }

    enum ScreenCaptureButtonState {
        case recording
        case idle

        var buttonColor: Color {
            switch self {
            case .recording: .red
            case .idle: .white
            }
        }
    }

    var drawingModesLayer: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                drawingModesInput
            }
            Spacer()
        }
    }

    var drawingModesInput: some View {
        ZStack(alignment: .center) {
            VStack(alignment: .center, spacing: 16) {
                drawingModeButton(for: .ui)
                drawingModeButton(for: .scribble)
                drawingModeButton(for: .line)
                drawingModeButton(for: .Angle)
                drawingModeButton(for: .arrow)
                revertButton
                colorPickerButton
            }
            .foregroundColor(.white)
            .padding([.vertical, .leading], 12)
            .padding(.trailing, 30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.black)
            )
            .offset(x: 20)
        }
    }

    func drawingModeButton(
        imageName: String,
        enabled: Bool = true,
        highlighted: Bool = false,
        action: @escaping () -> ()
    ) -> some View {
        Button {
            action()
            //MARK: - Add this condition for hide show on tap on Angle button
            if imageName == "checkmark"{
                angleShow = angleShow == false ? true : false
            }
        } label: {
            Image(systemName: imageName)
                .font(.title)
                .foregroundColor(highlighted ? drawColor : .white)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    func drawingModeButton(for inputMode: InputMode) -> some View {
        drawingModeButton(
            imageName: inputMode.systemImageName,
            highlighted: self.inputMode == inputMode
        ) {
            self.inputMode = inputMode
        }
    }

    var colorPickerButton: some View {
        ColorPicker("", selection: $drawColor, supportsOpacity: true)
            .frame(maxWidth: 24, maxHeight: 24)
    }

    var canRevert: Bool {
        !self.canvasAdditions.isEmpty
    }

    var revertButton: some View {
        drawingModeButton(
            imageName: "arrow.uturn.backward",
            enabled: canRevert
        ) {
            self.removeLastCanvasAddition()
        }
    }
}

// AVPlayer observers
extension AnnotatableVideoPlayer {
    
    var drawingAngle: some View {
        GeometryReader { geometry in
            AngleView(startPoint: $startPoint, endPoint1: $endPoint1, endPoint2: $endPoint2, color: $drawColor)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay(
                    Text("\(calculateAngle(start: endPoint1, end: endPoint2))°")
                        .padding(8)
                        .background(Color.clear)
                        .foregroundColor(Color.white)
                        .cornerRadius(8)
                        .position(x: startPoint.x, y: startPoint.y + 10)
                )
        }
    }
    
    private func handleDrag(value: DragGesture.Value) {
        let dragPoint = value.location
        if isTapped(point: startPoint, tapLocation: dragPoint) {
            updatePoints(withDragPoint: dragPoint)
        } else if isTapped(point: endPoint1, tapLocation: dragPoint) {
            endPoint1 = dragPoint
        } else if isTapped(point: endPoint2, tapLocation: dragPoint) {
            endPoint2 = dragPoint
        }
    }

    //MARK: - updatePoints using for update StartPoint location
    private func updatePoints(withDragPoint dragPoint: CGPoint) {
        let deltaX = dragPoint.x - startPoint.x
        let deltaY = dragPoint.y - startPoint.y
        
        startPoint = dragPoint
        endPoint1.x += deltaX
        endPoint1.y += deltaY
        endPoint2.x += deltaX
        endPoint2.y += deltaY
    }
    
    //MARK: - calculateAngle using for Calculate angle between endPoint1 and endPoint2
    private func calculateAngle(start: CGPoint, end: CGPoint) -> Int {
        let vector1 = CGVector(dx: endPoint1.x - startPoint.x, dy: endPoint1.y - startPoint.y)
        let vector2 = CGVector(dx: endPoint2.x - startPoint.x, dy: endPoint2.y - startPoint.y)
        
        let dotProduct = vector1.dx * vector2.dx + vector1.dy * vector2.dy
        let magnitude1 = sqrt(pow(vector1.dx, 2) + pow(vector1.dy, 2))
        let magnitude2 = sqrt(pow(vector2.dx, 2) + pow(vector2.dy, 2))
        
        // Ensure that the magnitude is not zero to prevent division by zero
        guard magnitude1 != 0 && magnitude2 != 0 else {
            return 0 // Return some default value when magnitudes are zero
        }
        
        let cosTheta = max(-1.0, min(1.0, dotProduct / (magnitude1 * magnitude2)))
        let theta = acos(cosTheta)
        
        var angleDegrees = Int(theta * 180 / .pi)
        
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        return angleDegrees
    }
    

    //MARK: - isTapped function is use
    private func isTapped(point: CGPoint, tapLocation: CGPoint) -> Bool {
        let distance = sqrt(pow(point.x - tapLocation.x, 2) + pow(point.y - tapLocation.y, 2))
        return distance < 30 // Adjust the threshold as needed
    }
    
    
    func setupObserver() {

    }

    func deinitPlayerAndObserver() {

    }
}

struct AngleView: View {
    @Binding var startPoint: CGPoint
    @Binding var endPoint1: CGPoint
    @Binding var endPoint2: CGPoint
    @Binding var color: Color
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: startPoint)
                path.addLine(to: endPoint1)
            }
            .stroke(color, lineWidth: 3)
            
            Path { path in
                path.move(to: startPoint)
                path.addLine(to: endPoint2)
            }
            .stroke(color, lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: 1.0) // Adjust the trim as needed
                .stroke(color, style: StrokeStyle(lineWidth: 5, dash: [5])) // Adjust the dash value as needed
                .frame(width: 32, height: 32)
                .position(positionOnEdge(startPoint: startPoint, endPoint: endPoint1))
            
            Circle()
                .trim(from: 0, to: 1.0) // Adjust the trim as needed
                .stroke(color, style: StrokeStyle(lineWidth: 5, dash: [5])) // Adjust the dash value as needed
                .frame(width: 32, height: 32)
                .position(positionOnEdge(startPoint: startPoint, endPoint: endPoint2))
        }
    }
    func positionOnEdge(startPoint: CGPoint, endPoint: CGPoint) -> CGPoint {
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let x = endPoint.x + 16 * cos(angle)
        let y = endPoint.y + 16 * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

struct Scribble {
    var points = [CGPoint]()
    var color: Color
    var lineWidth: Double = 1.0
}


struct Line {
    var start: CGPoint
    var end: CGPoint
    var color: Color

    var path: Path {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
    }
}

struct Arrow {
    var start: CGPoint
    var end: CGPoint
    var color: Color

    var path: Path {
        let arrowAngle: CGFloat = .pi/6
        let pointerLineLength: CGFloat = 20

        var path = Path()

        path.move(to: start)
        path.addLine(to: end)

        let startEndAngle = atan((end.y - start.y) / (end.x - start.x)) + ((end.x - start.x) < 0 ? CGFloat(Double.pi) : 0)
        let arrowLine1 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle + arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle + arrowAngle))
        let arrowLine2 = CGPoint(x: end.x + pointerLineLength * cos(CGFloat(Double.pi) - startEndAngle - arrowAngle), y: end.y - pointerLineLength * sin(CGFloat(Double.pi) - startEndAngle - arrowAngle))

        path.addLine(to: arrowLine1)
        path.move(to: end)
        path.addLine(to: arrowLine2)

        return path
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

struct AnnotatableVideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        AnnotatableVideoPlayer(url: .documentsDirectory)
    }
}


