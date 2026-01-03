//
//  ContentView.swift
//  QuranAudioPlayer
//
//  Created by Syed Muhammad Muzammil on 05/03/2025.
//
import SwiftUI
import AVFoundation

// MARK: - Audio File Model
struct AudioFile: Identifiable {
    let id = UUID()
    let name: String
    let fileName: String
    let playbackSpeed: Float // Each file has its own playback speed
}

struct ContentView: View {
    @State private var audioFiles: [AudioFile] = [] // List of audio files
    @State private var player: AVPlayer?
    @State private var selectedFile: AudioFile?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0.0
    @State private var totalTime: Double = 1.0 // Prevent divide by zero

    var body: some View {
        VStack {
            List(audioFiles) { file in
                Button(action: {
                    playAudio(file: file)
                }) {
                    Text(file.name)
                        .foregroundColor(selectedFile?.id == file.id ? .blue : .primary)
                }
            }
            .onAppear {
                loadAudioFiles()
            }

            if let selectedFile = selectedFile {
                VStack {
                    Text("Now Playing: \(selectedFile.name)")
                        .font(.headline)

                    // Seek Bar
                    Slider(value: $currentTime, in: 0...totalTime, onEditingChanged: { _ in
                        seekAudio()
                    })

                    // Play/Pause Button
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Load MP3 Files from Bundle
    func loadAudioFiles() {
        if let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            audioFiles = urls.compactMap { url in
                let fileName = url.deletingPathExtension().lastPathComponent
                let number = Int(fileName.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                let playbackSpeed: Float = (number == 30 || number == 59) ? 1.5 : 2

                return AudioFile(
                    name: getAudioMetadata(url: url) ?? fileName,
                    fileName: fileName,
                    playbackSpeed: playbackSpeed
                )
            }
            .sorted { (file1, file2) in
                let num1 = Int(file1.fileName.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                let num2 = Int(file2.fileName.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                return num1 < num2
            }

            if let firstFile = audioFiles.first {
                playAudio(file: firstFile) // Auto-play first file
            }
        }
    }

    // MARK: - Play Audio with Speed & Auto-Play Next Track
    func playAudio(file: AudioFile) {
        if selectedFile?.id == file.id, isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.player?.rate = file.playbackSpeed // ✅ Apply playback speed again
                print("Playback Speed Set: \(self.player?.rate ?? 1.0)")
            }
            return // Prevent restarting the same audio
        }

        selectedFile = file
        guard let url = Bundle.main.url(forResource: file.fileName, withExtension: "mp3") else {
            print("Audio file not found")
            return
        }

        player?.pause()
        player = AVPlayer(url: url)
        player?.automaticallyWaitsToMinimizeStalling = false // Prevents speed reset
        player?.play()
        isPlaying = true // ✅ Update play state when starting

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Delay ensures it applies
            self.player?.rate = file.playbackSpeed
            print("Playback Speed Set: \(self.player?.rate ?? 1.0)")
        }

        guard let duration = player?.currentItem?.asset.duration else { return }
        totalTime = CMTimeGetSeconds(duration)

        // Observe when track finishes & play next
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            self.playNextTrack()
        }

        // Update progress periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if let currentTime = player?.currentTime() {
                self.currentTime = CMTimeGetSeconds(currentTime)
            }
        }
    }

    // MARK: - Auto-Play Next Track
    func playNextTrack() {
        guard let currentIndex = audioFiles.firstIndex(where: { $0.id == selectedFile?.id }) else { return }

        let nextIndex = (currentIndex + 1) % audioFiles.count // Loop to first track after last
        let nextFile = audioFiles[nextIndex]

        playAudio(file: nextFile)
    }

    // MARK: - Play/Pause Toggle (Fix Button Update)
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false // ✅ Update play state
        } else {
            player.play()
            isPlaying = true // ✅ Update play state
            if let selectedFile {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.player?.rate = selectedFile.playbackSpeed // ✅ Apply playback speed again
                    print("Playback Speed Set: \(self.player?.rate ?? 1.0)")
                }
            }
        }
    }

    // MARK: - Seek Audio
    func seekAudio() {
        let newTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: 600)
        player?.seek(to: newTime)
    }
    
    // MARK: - Get Audio Metadata (Title)
    func getAudioMetadata(url: URL) -> String? {
        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata
        let titleItem = metadata.first { $0.commonKey == .commonKeyTitle }
        return titleItem?.stringValue
    }
}
