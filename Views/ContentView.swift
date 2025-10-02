//
//  ContentView.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 01/10/25.
//

import SwiftUI

struct ContentView: View {
    static let sourceConfiguration: SourceConfig = {
       SourceConfig(
        sourceUrl: "YOUR_SOURCE_URL",
        licenseUrl: "YOUR_LICENSE_URL",// optional
        certificateUrl: "YOUR_CERTIFICATE_URL",// optional
        headers:[:])
    }()
    let player = Player(sourceConfig: sourceConfiguration)
    var body: some View {
        PlayerViewController(player: player)
            .onAppear() {
                player.play()
            }
        .padding()
    }
}

#Preview {
    ContentView()
}
