# ViedeoAppAVPlayerVC  

This project demonstrates how to play **video content** in iOS using **AVPlayer** and **AVPlayerViewController**.  
It supports **both clear (unencrypted)** and **encrypted (FairPlay DRM-protected)** content.  
The project also showcases how to integrate **FairPlay Streaming (FPS)** license acquisition and use modern **async/await** patterns in Swift for handling network calls and DRM workflows.  

---

## 🚀 Features
- Playback using `AVPlayer` and `AVPlayerViewController`  
- **Supports both clear and encrypted content playback**  
- Integration with **FairPlay DRM** (certificate, SPC, CKC flow)  
- `AVContentKeySession` for handling content key requests  
- Async/await networking with `URLSession`  
- XML parsing for certificate/CKC extraction  
- Error handling with a dedicated `PlaybackError` enum  
- SwiftUI integration with `UIViewControllerRepresentable`  

---

## 📂 Project Structure
- **Player.swift** → Handles AVPlayer setup, content key session, DRM flow  
- **Parser.swift** → Parses XML responses (`<cert>` and `<ckc>` tags) and decodes base64 data  
- **PlayerViewController.swift** → A `UIViewControllerRepresentable` wrapper to use AVPlayer in SwiftUI  
- **PlaybackError.swift** → Centralized error definitions for playback and DRM handling  
- **SourceConfig.swift** → Configuration for source URL, license server, and headers  

---

## 🔑 DRM Workflow (FairPlay)
1. AVPlayer requests a key for encrypted content  
2. `AVContentKeySessionDelegate` provides the request  
3. App fetches **certificate** from the server  
4. SPC is generated and sent to the **license server**  
5. License server returns **CKC**  
6. CKC is processed and provided back to AVPlayer  
7. Encrypted content starts playback  

---

## 🛠 Requirements
- iOS 15+  
- Xcode 14+  
- Swift 5.7+  

---

## ▶️ Usage
1. Configure your **certificate URL** and **license server URL** in `SourceConfig`  
2. Run the app  
3. The player will automatically handle **clear playback** or perform the DRM flow for **encrypted playback**  

---

## 📌 Notes
- Supports both **raw CKC** and **XML-wrapped CKC** formats  
- Handles both **clear and encrypted content** seamlessly  
- Demonstrates error handling when URLs or responses are invalid  
- Designed for educational/demo purposes – adapt for production use  

## Search Topics
- avplayer, ios, swift, swiftUI, sample-app
