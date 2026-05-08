import SwiftUI
import AppKit

struct VLCVideoView: NSViewRepresentable {
    @ObservedObject var player: VLCPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // VLCKit native embedding:
        // By passing the view to LibVLC, it uses its internal MacVout to render via Metal/OpenGL
        DispatchQueue.main.async {
            player.bridge.setDrawable(view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle resizing if LibVLC requires it, 
        // though set_nsobject usually handles it automatically
    }
}
