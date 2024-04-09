//
//  ContentView.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 08/04/24.
//

import Foundation
import SwiftUI
import UIKit
import AVKit

struct ContentView: View {
    @State private var selectedMedia: Media?
    @State private var isShowingMediaPicker = false
    @State private var mediaItems: [Media] = []
    
//    var body: some View {
//        NavigationView {
//            VStack {
//                Button("Select Media") {
//                    self.isShowingMediaPicker = true
//                }
//                .padding()
//                
//                List(mediaItems, id: \.self) { media in
//                    ZStack {
//                        Color.black
//                            .edgesIgnoringSafeArea(.all)
//                        
//                        if media.mediaType == .image {
//                            Image(uiImage: media.image!)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 200, height: 200)
//                                .padding()
//                        } else if media.mediaType == .video {
//                            VideoPlayer(player: AVPlayer(url: media.videoURL!))
//                                .frame(width: 200, height: 200)
//                                .padding()
//                        }
//                    }
//                    .cornerRadius(10)
//                    .padding()
//                }
//            }
//            .navigationTitle("Media Picker")
//            .sheet(isPresented: $isShowingMediaPicker, onDismiss: loadMedia) {
//                MediaPicker(selectedMedia: self.$selectedMedia, isPresented: self.$isShowingMediaPicker)
//            }
//        }
//    }
//    var body: some View {
//        NavigationView {
//            VStack {
//                Button("Select Media") {
//                    self.isShowingMediaPicker = true
//                }
//                .padding()
//                
//                List(mediaItems, id: \.self) { media in
//                    ZStack {
//                        Color.black
//                            .edgesIgnoringSafeArea(.all)
//                        
//                        if let videoURL = media.videoURL {
//                            NavigationLink(destination: AnnotatableVideoPlayer(url: videoURL)) {
//                                VideoPlayer(player: AVPlayer(url: videoURL))
//                                    .onAppear {
//                                        // Mute the video player if needed
//                                        AVPlayer(url: videoURL).isMuted = true
//                                    }
//                                    .frame(width: 200, height: 200)
//                                    .padding()
//                            }
//                        } else if let image = media.image {
//                            Image(uiImage: image)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 200, height: 200)
//                                .padding()
//                        }
//                    }
//                    .cornerRadius(10)
//                    .padding()
//                }
//            }
//            .navigationTitle("Media Picker")
//            .sheet(isPresented: $isShowingMediaPicker, onDismiss: loadMedia) {
//                MediaPicker(selectedMedia: self.$selectedMedia, isPresented: self.$isShowingMediaPicker)
//            }
//        }
//    }
    var body: some View {
        NavigationView {
            VStack {
                Button("Select Media") {
                    self.isShowingMediaPicker = true
                }
                .padding()
                
                List(mediaItems, id: \.self) { media in
                    GeometryReader { geometry in
                        ZStack {
                            Color.black
                                .edgesIgnoringSafeArea(.all)
                            
                            NavigationLink(destination: AnnotatableVideoPlayer(url: media.videoURL ?? URL(fileURLWithPath: ""), imageView: media.image, feedViewModel: .init())) {
                                if let videoURL = media.videoURL {
                                    VideoPlayerView(player: AVPlayer(url: videoURL))
                                        .onAppear {
                                            AVPlayer(url: videoURL).isMuted = true
                                        }
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .padding()
                                        .background(Color.black)
                                } else if let image = media.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .padding()
                                        .background(Color.black)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(Rectangle())
                        }
                        .cornerRadius(10)
                        .padding()
                    }
                    .frame(height: 200)
                }
            }
            .navigationTitle("Media Picker")
            .sheet(isPresented: $isShowingMediaPicker, onDismiss: loadMedia) {
                MediaPicker(selectedMedia: self.$selectedMedia, isPresented: self.$isShowingMediaPicker)
            }
        }
    }
    
    func loadMedia() {
        guard let selectedMedia = selectedMedia else { return }
        mediaItems.insert(selectedMedia, at: 0) // Prepend the selected media to the array
        self.selectedMedia = nil
    }
}

struct MediaPicker: UIViewControllerRepresentable {
    @Binding var selectedMedia: Media?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let mediaPicker = UIImagePickerController()
        mediaPicker.sourceType = .photoLibrary
        mediaPicker.mediaTypes = ["public.image", "public.movie"]
        mediaPicker.delegate = context.coordinator
        return mediaPicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: MediaPicker
        
        init(parent: MediaPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedMedia = Media(mediaType: .image, image: image, videoURL: nil)
            } else if let videoURL = info[.mediaURL] as? URL {
                parent.selectedMedia = Media(mediaType: .video, image: nil, videoURL: videoURL)
            }
            parent.isPresented = false
        }
    }
}

struct Media: Hashable {
    enum MediaType {
        case image
        case video
    }
    
    let id = UUID() // Add unique identifier
    
    let mediaType: MediaType
    let image: UIImage?
    let videoURL: URL?
    var imageURL: URL?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Media, rhs: Media) -> Bool {
        return lhs.id == rhs.id
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false // Hide native playback controls
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update the view controller if needed
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
