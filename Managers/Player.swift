//
//  Player.swift
//  PlaybackWithAVPlayerVC
//
//  Created by Karthi on 01/10/25.
//
import AVKit
import AVFoundation

class Player: NSObject {
    
    // AVPlayer object for handling playback
    private var player: AVPlayer? = nil
    private let sourceConfig: SourceConfig
    
    init(sourceConfig: SourceConfig) {
        self.sourceConfig = sourceConfig
    }
    
    // ContentKeySession for handling key requests
    private lazy var contentKeySession: AVContentKeySession = {
        let contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        contentKeySession.setDelegate(self, queue: DispatchQueue(label: "ContentKeyQueue"))
        return contentKeySession
    }()
    
    
    // URLSession for network requests
    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default)
    }()
    
    func prepareAndPlay() -> AVPlayer? {
        guard let sourceUrl = URL(string: sourceConfig.sourceUrl) else {
            print("Invalid source Url")
            return nil
        }
        
        // Asset and player initialization
        let asset = AVURLAsset(url: sourceUrl)
        self.contentKeySession.addContentKeyRecipient(asset)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Adding observer for status handling
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .initial], context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: [.new], context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferFull), options: [.new], context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp), options: [.new], context: nil)
        player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playbackFailed(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        return player
    }
    
    // For the given licenseUrl and contentId return the licenseUrl with contentId
    private func getLicenseUrlWithContentId(licenseUrl: String, contentId: String) -> URL? {
        guard var urlComponents = URLComponents(string: licenseUrl) else { return nil }
        var urlQueryItems = urlComponents.queryItems ?? []
        //urlQueryItems.append(URLQueryItem(name: "key_id", value: contentId))
        urlComponents.queryItems = urlQueryItems
        return urlComponents.url
    }
    
    func play() {
        player?.play()
    }
}

// AVContentKeySessionDelegate Hanlder
extension Player: AVContentKeySessionDelegate {
    // This delegate callback is called when the client initiates a key request.
    // It is also triggered when AVFoundation determines that the content is encrypted
    // based on the playlist provided by the client during playback request.
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        guard let certificateUrl = self.sourceConfig.certificateUrl else {
            print("-> ERROR: CertUrl is empty")
            keyRequest.processContentKeyResponseError(PlaybackError.certUrlEmpty)
            return
        }
        
        guard let licenseUrl = self.sourceConfig.licenseUrl else {
            print("-> ERROR: LicenseUrl is empty")
            keyRequest.processContentKeyResponseError(PlaybackError.licenseUrlMissing)
            return
        }
        
        // Extract contentId from the skd:// URL and get licenseUrl with contentId appended to it
        guard let skdUrl = keyRequest.identifier as? String,
              let contentId = skdUrl.replacingOccurrences(of: "skd://", with: "") as String?,
              let contentIdData = contentId.data(using: .utf8),
              let certificateUrl = URL(string: certificateUrl),
              let licenseUrlWithContentId = getLicenseUrlWithContentId(licenseUrl: licenseUrl, contentId: contentId) else {
            print("-> ERROR: Failed to get contentId or form a licenseUrl with contentId!")
            keyRequest.processContentKeyResponseError(PlaybackError.invalidContentIdOrSKD)
            return
        }

        // Get licenseUrl with contentId appended to it
        print("-> contentId: \(contentId)")
        print("-> certificateUrl: \(certificateUrl)")
        print("-> licenseUrlWithContentId: \(licenseUrlWithContentId)")
        
        Task { [weak self, weak keyRequest] in
            guard let self, let keyRequest else { return }
            
            guard let certData = await self.getCertificate(certificateUrl: certificateUrl) else {
                print("-> ERROR: Cert is empty")
                keyRequest.processContentKeyResponseError(PlaybackError.certDataEmpty)
                return
            }
            
            do {
                // 1) Create SPC using the async API
                let spcData = try await keyRequest.makeStreamingContentKeyRequestData(forApp: certData, contentIdentifier: contentIdData, options: nil)
                print("-> SPC generated, size: \(spcData.count) bytes")
                
                // 2) Get CKC from key server.
                let data = try await getLicense(licenseUrl: licenseUrlWithContentId, spcData: spcData.base64EncodedString())
                
                // 3) Interpret CKC from response.
                // Some license servers return raw CKC data; others return XML with <ckc> base64.
                // Try parsing as XML <ckc> first
                let ckcData = Parser().parseData(data: data)
                
                // 4) Provide the CKC to AVFoundation
                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                keyRequest.processContentKeyResponse(keyResponse)
                
            } catch {
                print("-> ERROR: Failed to obtain/process CKC: \(error.localizedDescription)")
                keyRequest.processContentKeyResponseError(error)
            }
        }

    }
    
}

// Http request Handler
private extension Player {
    // FPS Certificate request
    func getCertificate(certificateUrl: URL) async -> Data? {
        var certificateRequest = URLRequest(url: certificateUrl)
        certificateRequest.httpMethod = "GET"
        do {
            let (data, response) = try await self.urlSession.data(for: certificateRequest)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                print("-> ERROR: Failed to get certificate: server error")
                return nil
            }
            return Parser().parseData(data: data)
        } catch {
            print("-> ERROR: Failed to get certificate: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getLicense(licenseUrl: URL, spcData: String) async throws -> Data {
        // Send SPC to the license server to obtain CKC
        var request = URLRequest(url: licenseUrl)
        request.httpMethod = "POST"
        // Commonly required headers for FairPlay license servers; adjust if your server differs.
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        // Merge any custom headers from your SourceConfig
        for (key, value) in self.sourceConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = spcData.data(using: .utf8)
        
        let (data, response) = try await self.urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("-> ERROR: License server returned status \(status)")
            throw PlaybackError.linceServerError
        }
        return data
    }
}

// Observer handling
extension Player {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let item = object as? AVPlayerItem {
            
            if keyPath == #keyPath(AVPlayerItem.status) {
                switch item.status {
                case .readyToPlay:
                    print("Item is ready to play")
                case .failed:
                    print("Item failed to play \(String(describing: item.error?.localizedDescription))")
                    if let errorLog = item.errorLog() {
                        for event in errorLog.events {
                            print("📄 AVPlayerItemErrorLogEvent:")
                            print(" date: \(String(describing: event.date))")
                            print(" URI: \(String(describing: event.uri))")
                            print(" ServerAddress: \(String(describing: event.serverAddress))")
                            print(" PlaybackSessionID: \(String(describing: event.serverAddress))")
                            print(" ErrorStatusCode: \(String(describing: event.errorStatusCode))")
                            print(" ErrorDomain: \(String(describing: event.errorDomain))")
                            print(" ErrorComment: \(String(describing: event.errorComment))")
                        }
                    }
                    if let error = item.error as NSError? {
                        print("📛 Error domain: \(error.domain)")
                        print("📛 Error code: \(error.code)")
                    }
                case .unknown:
                    print("Item status unknown")
                @unknown default:
                    fatalError()
                }
            } else if keyPath == #keyPath(AVPlayerItem.isPlaybackBufferEmpty) {
                print("Item isPlaybackBufferEmpty")
            } else if keyPath == #keyPath(AVPlayerItem.isPlaybackBufferFull) {
                print("Item isPlaybackBufferFull")
            } else if keyPath == #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp) {
                print("Item isPlaybackLikelyToKeepUp")
            }
            
        } else if let player = object as? AVPlayer {
            if keyPath == #keyPath(AVPlayer.timeControlStatus) {
                if player.timeControlStatus == .playing {
                    print("▶️ Now playing")
                } else if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    print("⏳ Buffering or waiting")
                } else if player.timeControlStatus == .paused {
                    print("⏸️ Paused")
                }
            }
        }
        
    }
    
    @objc private func playbackFailed(_ notification: Notification) {
        guard let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError else {
            return
        }
        print("❌ Playback failed: \(error.localizedDescription)")
    }
}
