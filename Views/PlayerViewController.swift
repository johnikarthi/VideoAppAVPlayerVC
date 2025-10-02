//
//  PlayerViewController.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 01/10/25.
//

import SwiftUI
import AVKit
struct PlayerViewController: UIViewControllerRepresentable {
    let player: Player
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        if let avPlayer = player.prepareAndPlay() {
            controller.player = avPlayer
        }
        controller.showsPlaybackControls = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}
