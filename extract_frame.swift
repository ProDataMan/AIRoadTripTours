#!/usr/bin/env swift

import AVFoundation
import AppKit

let videoPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AIRoadTripTours.mp4"
let outputPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "app_icon_1024.png"

let url = URL(fileURLWithPath: videoPath)
let asset = AVAsset(url: url)
let imageGenerator = AVAssetImageGenerator(asset: asset)
imageGenerator.appliesPreferredTrackTransform = true

let time = CMTime(seconds: 1.0, preferredTimescale: 600)

do {
    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 1024, height: 1024))

    guard let tiffData = nsImage.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Error: Failed to convert image")
        exit(1)
    }

    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Success: Extracted frame to \(outputPath)")
} catch {
    print("Error: \(error)")
    exit(1)
}
