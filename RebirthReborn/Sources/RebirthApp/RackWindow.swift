import SwiftUI
import AppKit

struct RackWindow: NSViewRepresentable {
    var zoom:Double
    var revision:Int
    func makeNSView(context:Context)->RackWindowAnchor{let view=RackWindowAnchor();view.zoom=zoom;view.revision=revision;return view}
    func updateNSView(_ view:RackWindowAnchor,context:Context){view.setZoom(zoom,revision:revision)}
}
final class RackWindowAnchor:NSView {
    var zoom=1.25
    var revision=0
    private weak var configuredWindow:NSWindow?
    override func viewDidMoveToWindow(){
        super.viewDidMoveToWindow()
        guard let window,configuredWindow !== window else{return}
        configuredWindow=window
        // The rack occupies the content area, never the title bar's safe area.
        window.styleMask.remove(.fullSizeContentView)
        window.titlebarAppearsTransparent=false
        window.contentAspectRatio=NSSize(width:592,height:510)
        window.contentMinSize=NSSize(width:592,height:510)
        window.contentMaxSize=NSSize(width:1184,height:1020)
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenNone)
        window.backgroundColor=NSColor(calibratedRed:0.27,green:0.35,blue:0.36,alpha:1)
        window.title="Rebirth Reborn"
        applyZoom()
    }
    func setZoom(_ value:Double,revision:Int){guard abs(zoom-value)>0.001 || self.revision != revision else{return};zoom=value;self.revision=revision;applyZoom()}
    private func applyZoom(){
        guard let window=configuredWindow else{return}
        let visible=window.screen?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
        let titleHeight=window.frame.height-window.contentLayoutRect.height
        let scale=min(max(1,zoom),min(visible.width/592,(visible.height-titleHeight-1)/510))
        let origin=window.frame.origin,top=window.frame.maxY
        window.setContentSize(NSSize(width:592*scale,height:510*scale))
        var frame=window.frame
        frame.origin.x=min(max(visible.minX,origin.x),visible.maxX-frame.width)
        frame.origin.y=min(max(visible.minY,top-frame.height),visible.maxY-frame.height)
        window.setFrame(frame,display:true)
    }
}

// Measures the usable SwiftUI viewport rather than the outer window content view.
struct RackViewport:NSViewRepresentable {
    func makeNSView(context:Context)->RackViewportProbe{RackViewportProbe()}
    func updateNSView(_ view:RackViewportProbe,context:Context){}
}
final class RackViewportProbe:NSView {
    override func hitTest(_ point:NSPoint)->NSView?{nil}
}
