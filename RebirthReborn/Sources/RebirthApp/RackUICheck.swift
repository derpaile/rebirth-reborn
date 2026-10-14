import SwiftUI
import AppKit
import RebirthModel

// Optional development check. No mouse or keyboard events are sent to the desktop.
enum RackUICheck {
    @MainActor static func run(_ studio:Studio) async {
        do {
            guard let window=NSApplication.shared.windows.first(where:{$0.title=="Rebirth Reborn"}),let content=window.contentView else{throw Failure("Rack window missing")}
            func anchor(_ view:NSView)->RackWindowAnchor?{if let match=view as? RackWindowAnchor{return match};return view.subviews.compactMap{anchor($0)}.first}
            func viewport(_ view:NSView)->RackViewportProbe?{if let match=view as? RackViewportProbe{return match};return view.subviews.compactMap{viewport($0)}.first}
            guard let usable=viewport(content) else{throw Failure("Usable rack viewport missing")}
            guard let sizing=anchor(content) else{throw Failure("Window sizing attachment missing")}
            for (revision,zoom) in [1.0,1.25,1.5,2.0].enumerated(){
                sizing.setZoom(zoom,revision:revision+100)
                try await Task.sleep(nanoseconds:50_000_000)
                content.layoutSubtreeIfNeeded()
                let size=usable.bounds.size
                let scale=min(size.width/592,size.height/510)
                guard 510*scale<=size.height+0.01,592*scale<=size.width+0.01 else{throw Failure("Rack bottom outside usable viewport: \(size)")}
                let layout=window.contentLayoutRect
                guard window.frame.minY>=window.screen!.visibleFrame.minY-1,abs(layout.height-size.height)<1 else{throw Failure("Window/title bar clips rack viewport")}
                print("UI_VIEWPORT: zoom=\(zoom), usable=\(size.width)×\(size.height), rack bottom=\(510*scale)")
                guard abs(size.width/size.height-592.0/510)<0.003,size.width>=592,size.height>=510 else{throw Failure("Rack proportions: \(size)")}
            }
            sizing.setZoom(1.25,revision:200)
            let input=RackControlMouseView(frame:NSRect(x:0,y:0,width:30,height:30))
            var value=64.0
            input.value=Binding(get:{value},set:{value=$0});input.range=0...127;input.reset=64
            func key(_ code:UInt16,_ modifiers:NSEvent.ModifierFlags=[])->NSEvent{NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:modifiers,timestamp:0,windowNumber:0,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:code)!}
            input.keyDown(with:key(126));guard value==65 else{throw Failure("Arrow increment")}
            input.keyDown(with:key(125,.shift));guard abs(value-64.9)<0.0001 else{throw Failure("Fine arrow decrement")}
            value=127;input.keyDown(with:key(126));guard value==127 else{throw Failure("Upper bound")}
            let doubleClick=NSEvent.mouseEvent(with:.leftMouseDown,location:CGPoint(x:10,y:10),modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:2,pressure:0)!
            input.mouseDown(with:doubleClick);guard value==64 else{throw Failure("Double-click reset")}
            input.relative=false;input.setFrameSize(NSSize(width:15,height:46))
            let trackClick=NSEvent.mouseEvent(with:.leftMouseDown,location:CGPoint(x:8,y:46),modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:0)!
            input.mouseDown(with:trackClick);guard value==127 else{throw Failure("Fader end position")}
            let previous=studio.song
            let hats=studio.drumControl(device:1,parameter:22)
            hats.wrappedValue=31
            let restored=try RebirthSongFile.read(RebirthSongFile.write(studio.song))
            guard abs(restored.drums[1].voices[7].level*127-31)<0.001,abs(restored.drums[1].voices[8].level*127-31)<0.001 else{throw Failure("Drum level persistence/shared hats")}
            studio.song=previous;studio.sync()
            let renderer=ImageRenderer(content:OriginalRack(studio:studio).environment(\.rackArtworkPreview,true))
            renderer.scale=2
            guard let image=renderer.nsImage,let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]),bitmap.pixelsWide==1184,bitmap.pixelsHigh==1020 else{throw Failure("Retina rack render")}
            try png.write(to:URL(fileURLWithPath:"/tmp/rebirth-reborn-ui-check.png"))
            print("UI_CHECK_PASS: four usable viewport scales including bottom edge/title bar, keyboard/fine input, range bounds, double-click reset, fader range, saved drum levels/shared hats, 1184 × 1020 render")
            NSApplication.shared.terminate(nil)
        } catch {print("UI_CHECK_FAIL: \(error)");exit(1)}
    }
    struct Failure:Error,CustomStringConvertible {let description:String;init(_ message:String){description=message}}
}
