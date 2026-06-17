//
//  CameraPreview.swift
//  BehavioralCoach
//
//  SwiftUI bridge for the live camera feed. Hosts an AVCaptureVideoPreviewLayer
//  by making it the backing layer of a UIView subclass (layerClass), which
//  avoids the resize/layout bugs of adding the preview layer as a sublayer.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
