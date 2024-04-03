//
//  VideoEditorApp.swift
//  VideoEditor
//
//  Created by Jay Ghervada on 03/04/24.
//

import SwiftUI

@main
struct VideoEditorApp: App {
    var body: some Scene {
        WindowGroup {
            AnnotatableVideoPlayer(url: .documentsDirectory)
        }
    }
}
