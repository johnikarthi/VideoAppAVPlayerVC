//
//  AppDelegate.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 02/10/25.
//

import SwiftUI
import AVKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        handleAudioSessionCategorySetting()
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    func handleAudioSessionCategorySetting() {
        let audioSession = AVAudioSession.sharedInstance()

        // When AVAudioSessionCategoryPlayback is already active, we have nothing to do here
        guard audioSession.category.rawValue != AVAudioSession.Category.playback.rawValue else {
            return
        }

        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: .moviePlayback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }
}
