import AppKit
import SwiftUI

// Draw the original faceplates at four times their source resolution.
// Logical coordinates remain 592 × 510; cached plates never redraw during playback.
enum RackDrawing {
    private static var cache:[Int:NSImage]=[:]
    static func plate(_ id:Int)->NSImage? {
        if let cached=cache[id]{return cached}
        let dimensions:[Int:CGSize]=[12057:CGSize(width:592,height:50),12058:CGSize(width:70,height:115),12500:CGSize(width:366,height:115),12520:CGSize(width:366,height:115),12564:CGSize(width:366,height:115),12060:CGSize(width:70,height:115),12061:CGSize(width:82,height:98),12064:CGSize(width:82,height:111),12063:CGSize(width:82,height:93),12065:CGSize(width:82,height:65),12569:CGSize(width:82,height:93)]
        guard let size=dimensions[id],let context=CGContext(data:nil,width:Int(size.width*4),height:Int(size.height*4),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        context.scaleBy(x:4,y:4);context.translateBy(x:0,y:size.height);context.scaleBy(x:1,y:-1)
        let previous=NSGraphicsContext.current
        NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:true)
        draw(id,size,context)
        NSGraphicsContext.current=previous
        guard let rendered=context.makeImage() else{return nil}
        let image=NSImage(cgImage:rendered,size:size);cache[id]=image;return image
    }
    private static let ink=NSColor(white:0.08,alpha:1), silver=NSColor(white:0.86,alpha:1)
    private static let blue=NSColor(calibratedRed:0.27,green:0.35,blue:0.36,alpha:1)
    private static let cream=NSColor(calibratedRed:0.89,green:0.87,blue:0.80,alpha:1)
    private static let orange=NSColor(calibratedRed:0.86,green:0.32,blue:0.10,alpha:1)
    private static func fill(_ rect:CGRect,_ color:NSColor,_ c:CGContext){c.setFillColor(color.cgColor);c.fill(rect)}
    private static func line(_ a:CGPoint,_ b:CGPoint,_ color:NSColor,_ c:CGContext,_ width:CGFloat=0.5){c.setStrokeColor(color.cgColor);c.setLineWidth(width);c.move(to:a);c.addLine(to:b);c.strokePath()}
    private static func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=6,_ color:NSColor=ink,_ weight:NSFont.Weight = .bold,_ centered:Bool=true) {
        let font=NSFont.monospacedSystemFont(ofSize:size,weight:weight)
        let string=NSAttributedString(string:value,attributes:[.font:font,.foregroundColor:color])
        let measured=string.size()
        string.draw(at:CGPoint(x:centered ? x-measured.width/2:x,y:y-measured.height/2))
    }
    private static func surface(_ size:CGSize,_ top:NSColor,_ bottom:NSColor,_ c:CGContext){
        let colors=[top.cgColor,bottom.cgColor] as CFArray
        if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1]){c.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:0,y:size.height),options:[])}
        line(CGPoint(x:0.5,y:0.5),CGPoint(x:size.width-0.5,y:0.5),.white.withAlphaComponent(0.65),c)
        line(CGPoint(x:0.5,y:0.5),CGPoint(x:0.5,y:size.height-0.5),.white.withAlphaComponent(0.4),c)
        line(CGPoint(x:0,y:size.height-0.5),CGPoint(x:size.width,y:size.height-0.5),.black,c)
        line(CGPoint(x:size.width-0.5,y:0),CGPoint(x:size.width-0.5,y:size.height),.black,c)
    }
    private static func button(_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ height:CGFloat,_ c:CGContext,_ color:NSColor=silver){
        let rect=CGRect(x:x-width/2,y:y-height/2,width:width,height:height)
        fill(rect,.black.withAlphaComponent(0.8),c)
        fill(rect.insetBy(dx:1,dy:1),color,c)
        line(CGPoint(x:rect.minX+1,y:rect.minY+1),CGPoint(x:rect.maxX-1,y:rect.minY+1),.white.withAlphaComponent(0.8),c)
        line(CGPoint(x:rect.minX+1,y:rect.maxY-2),CGPoint(x:rect.maxX-1,y:rect.maxY-2),.black.withAlphaComponent(0.25),c)
    }
    private static func well(_ x:CGFloat,_ y:CGFloat,_ digits:Int,_ c:CGContext){fill(CGRect(x:x-CGFloat(digits)*4.5-1,y:y-9,width:CGFloat(digits)*9+2,height:18),ink,c)}
    private static func lamp(_ x:CGFloat,_ y:CGFloat,_ c:CGContext){c.setFillColor(NSColor(white:0.09,alpha:1).cgColor);c.fillEllipse(in:CGRect(x:x-2,y:y-2,width:4,height:4))}
    private static func arrow(_ x:CGFloat,_ y:CGFloat,_ up:Bool,_ c:CGContext){button(x,y,8,8,c);c.setFillColor(ink.cgColor);c.move(to:CGPoint(x:x-2.5,y:y+(up ? 1.5:-1.5)));c.addLine(to:CGPoint(x:x+2.5,y:y+(up ? 1.5:-1.5)));c.addLine(to:CGPoint(x:x,y:y+(up ? -2:2)));c.closePath();c.fillPath()}
    private static func scale(_ x:CGFloat,_ y:CGFloat,_ radius:CGFloat,_ c:CGContext){for i in 0..<11{let angle=(Double(i)*27+135)*Double.pi/180;line(CGPoint(x:x+CGFloat(Darwin.cos(angle))*(radius+1),y:y+CGFloat(Darwin.sin(angle))*(radius+1)),CGPoint(x:x+CGFloat(Darwin.cos(angle))*(radius+3),y:y+CGFloat(Darwin.sin(angle))*(radius+3)),ink,c,0.7)}}
    private static func header(_ title:String,_ width:CGFloat,_ c:CGContext,_ mixer:Bool=false){
        fill(CGRect(x:3,y:4,width:width-6,height:12),mixer ? NSColor(calibratedRed:0.47,green:0.43,blue:0.08,alpha:1):NSColor(calibratedRed:0.12,green:0.22,blue:0.49,alpha:1),c)
        text(title,width/2,10,8,.white,.medium);lamp(14,10,c)
        for i in 0..<3{fill(CGRect(x:width-12,y:6+CGFloat(i)*3,width:5,height:2),ink,c)}
    }
    private static func draw(_ id:Int,_ size:CGSize,_ c:CGContext){
        switch id {
        case 12057:
            surface(size,blue,NSColor(calibratedRed:0.17,green:0.23,blue:0.23,alpha:1),c)
            for (label,x,y) in [("Sync",50.0,8.0),("MIDI",79,8),("Pattern",146,9),("Song mode",207,9),("Tempo",56,20),("Bar",284,21),("Loop",351,8),("Start",347,21),("Length",389,21),("SHUFFLE",21,42)]{text(label,x,y,label=="SHUFFLE" ? 5:7,.white,.medium)}
            for x:CGFloat in [45,77,173,181,320]{lamp(x,11,c)}
            well(58,34,3,c);arrow(78,30,true,c);arrow(78,39,false,c)
            for (i,x) in [112.0,143,175,207,239].enumerated(){
                button(x,34,32,23,c,blue.blended(withFraction:0.5,of:.white)!)
                if i==1{fill(CGRect(x:x-2,y:32,width:4,height:4),NSColor.brown,c)}
                if i==2 || i==3{text(i==2 ? "◀◀":"▶▶",x,34,9,ink)}
            }
            for x:CGFloat in [284,347,389]{well(x,35,3,c);arrow(x+21,30,true,c);arrow(x+21,39,false,c)}
        case 12058:
            surface(size,blue,blue.blended(withFraction:0.30,of:.black)!,c)
            fill(CGRect(x:5,y:3,width:60,height:15),NSColor(calibratedRed:0.54,green:0.08,blue:0.16,alpha:1),c)
            text("PATTERN",39,10,8,.white,.bold);lamp(12,10,c)
            for n in 0..<8{let x=CGFloat(12+n%4*15),y=CGFloat(32+n/4*15);button(x,y,13,13,c);text("\(n+1)",x,y,7)}
            text("BANK",16,62,5,.white,.bold)
            for n in 0..<4{let x=CGFloat(12+n*15);button(x,75,13,13,c);text(["A","B","C","D"][n],x,75,7)}
            text("SHUFFLE",19,92,5,.white);text("STEPS",47,92,5,.white)
            button(12,103,13,13,c);well(45,103,2,c);arrow(62,99,true,c);arrow(62,107,false,c)
        case 12500:
            surface(size,NSColor(white:0.94,alpha:1),NSColor(white:0.77,alpha:1),c)
            line(CGPoint(x:0,y:44),CGPoint(x:366,y:44),ink,c,0.8);line(CGPoint(x:66,y:0),CGPoint(x:66,y:43),ink,c)
            text("WAVEFORM",33,7,6);text("╲╲ ▯▯",33,18,11,ink,.medium)
            for (i,x) in [86.0,119,152,186,220,254].enumerated(){text(["TUNE","CUTOFF","RESO","ENV.MOD","DECAY","ACCENT"][i],x,7,6);scale(x,27,12,c)}
            line(CGPoint(x:270,y:0),CGPoint(x:270,y:43),ink,c)
            text("EDIT",338,12,6);text("STEP",338,20,6);well(338,33,2,c)
            fill(CGRect(x:6,y:48,width:39,height:38),ink,c);text("PITCH",25,56,6,.white);text("MODE",25,64,6,.white);button(27,79,20,8,c)
            text("CLEAR",26,92,6);button(27,101,21,9,c)
            fill(CGRect(x:48,y:48,width:164,height:63),ink,c)
            let whites:[CGFloat]=[55,77,98,119,141,162,183,203],blacks:[CGFloat]=[66,88,130,152,174]
            for x in whites{fill(CGRect(x:x-8,y:50,width:17,height:34),.white,c);lamp(x,86,c);button(x,98,11,19,c)}
            for x in blacks{fill(CGRect(x:x-5,y:50,width:10,height:23),ink,c);button(x,65,5,16,c);lamp(x,56,c)}
            line(CGPoint(x:215,y:47),CGPoint(x:215,y:113),ink,c)
            text("♪",235,65,18,ink,.regular);text("♯",285,65,18,ink,.regular);lamp(250,66,c);lamp(293,66,c);button(308,66,13,8,c)
            fill(CGRect(x:216,y:74,width:102,height:7),ink,c)
            for (name,x) in [("DOWN",229.0),("UP",253),("ACCENT",278),("SLIDE",304)]{text(name,x,78,4.5,.white);lamp(x,83,c);button(x,97,10,20,c)}
            line(CGPoint(x:319,y:48),CGPoint(x:319,y:112),ink,c)
            text("BACK",338,58,6);button(338,68,20,8,c);text("STEP",338,87,6);button(338,98,22,17,c)
        case 12520:
            surface(size,NSColor(calibratedRed:0.22,green:0.23,blue:0.20,alpha:1),NSColor(calibratedRed:0.13,green:0.14,blue:0.12,alpha:1),c)
            let pale=NSColor(calibratedRed:0.96,green:0.92,blue:0.74,alpha:1)
            for i in 0..<12{text("LEVEL",CGFloat(18+i*22),5,5,pale)}
            let names=["AC","BD","SD","LT","MT","HT","RS","CP","CB","CY","OH","CH"]
            for (i,name) in names.enumerated(){let x=CGFloat(20+i*22);button(x,78,19,10,c,pale);text(name,x,78,6)}
            for (name,x,y) in [("TONE",44.0,26.0),("TONE",66,26),("TUNE",88,26),("TUNE",110,26),("TUNE",132,26),("DECAY",44,47),("SNAPPY",66,47),("TONE",220,26),("DECAY",220,47),("DECAY",242,47)]{text(name,x,y,5,pale)}
            for (name,x) in [("LC",88.0),("MC",110),("HC",132),("CL",154),("MA",176)]{button(x,48,16,10,c,pale);text(name,x,48,5)}
            for i in 0..<16{let x=CGFloat(21+i*16);let color:[NSColor]=[NSColor.systemRed,.systemOrange,.systemYellow,.white];button(x,101,13,21,c,color[i/4]);lamp(x,94,c)}
            let selector=["AC","BD","SD","LT","MT","HT","RS","CP","CB","CY","OH","CH"]
            for i in 0..<12{let angle=(Double(i)*27+100)*Double.pi/180;let x=320+Darwin.cos(angle)*27,y=62+Darwin.sin(angle)*23;text(selector[i],x,y,5,pale)}
        case 12564:
            surface(size,cream,cream.blended(withFraction:0.12,of:.black)!,c)
            fill(CGRect(x:5,y:3,width:356,height:11),ink,c)
            for (name,x) in [("AC",15.0),("BD",45),("SD",88),("LT",130),("MT",173),("HT",215),("RS",247),("CP",268),("CH",289),("OH",310),("CC",331),("RC",352)]{text(name,x,9,6,orange)}
            for x:CGFloat in [35,78,120,163,205]{text("TUNE",x,23,5);text("LEVEL",x+21,23,5)}
            for x:CGFloat in [247,268,289,310,331,352]{text("LEVEL",x,23,4.5)}
            for (name,x) in [("ATT",35.0),("DEC",56),("TONE",78),("SNAP",99),("DEC",130),("DEC",173),("DEC",215),("DEC",289),("DEC",310),("TUNE",331),("TUNE",352)]{text(name,x,49,5)}
            text("FLAM",15,69,5);button(15,54,18,7,c);text("+ AC",15,54,4)
            for i in 0..<16{let x=CGFloat(36+i*21);button(x,99,18,19,c);lamp(x,91,c);text("\(i+1)",x,111,5)}
            for (name,x,w) in [("BASS DRUM",45.0,39.0),("SNARE DRUM",88,39),("LOW TOM",130,39),("MID TOM",173,39),("HI TOM",215,39),("RS",247,18),("CP",268,18),("CH",289,18),("OH",310,18),("CC",331,18),("RC",352,18)]{button(x,80,w,7,c);text(name,x,80,3.5)}
        case 12060:
            surface(size,blue,blue.blended(withFraction:0.18,of:.black)!,c);header("MIX",70,c,true)
            text("L",9,49,5,.white);text("R",29,49,5,.white);text("PAN",19,57,6,.white)
            text("DELAY",51,109,5,.white)
            for (name,y) in [("DIST",45.0),("PCF",62),("COMP",77)]{text(name,51,y,5,.white);button(54,y+6,17,6,c);lamp(59,y+6,c)}
        case 12061:
            surface(size,blue,blue.blended(withFraction:0.20,of:.black)!,c);header("MASTER",82,c,true)
            for n in 0..<7{let y=CGFloat(29+n*7);text(n==0 ? "Clip":"−\(n*6)",12,y,5,.white,.regular);text(n==0 ? "Clip":"−\(n*6)",73,y,5,.white,.regular)}
            text("COMP",29,88,5,.white);button(46,88,15,6,c);lamp(62,88,c)
        default:
            surface(size,blue,blue.blended(withFraction:0.18,of:.black)!,c)
            let title=id==12064 ? "PCF":id==12063 ? "DELAY":id==12065 ? "DIST":"COMP"
            header(title,82,c)
            if id==12064 {
                well(20,32,2,c);arrow(34,27,true,c);arrow(34,37,false,c);text("PATTERN",20,48,5,.white)
                text("BP",66,27,5,.white);text("LP",66,37,5,.white);text("MODE",64,48,5,.white);button(58,33,6,18,c)
                for (i,name) in ["FREQ","Q","AMT","DEC"].enumerated(){text(name,CGFloat(14+i*18),104,5,.white)}
            } else if id==12063 {
                well(18,32,2,c);arrow(34,27,true,c);arrow(34,37,false,c);text("STEPS",18,48,5,.white);text("♪³",64,30,11,.white,.regular);button(55,33,5,18,c)
                text("PAN",20,84,6,.white);text("F.BACK",61,84,6,.white)
            } else if id==12065 {text("AMOUNT",20,55,5,.white);text("SHAPE",61,55,5,.white)}
            else{
                for i in 0..<9{lamp(CGFloat(11+i*7),36,c)}
                text("−40  0  +20 +40",41,47,4,.white,.regular);text("RATIO",20,84,6,.white);text("THRES",61,84,6,.white)
            }
        }
    }
}

struct RackSevenSegment:View {
    let digit:Int
    var body:some View{
        Canvas{context,size in
            let masks=[0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f]
            let paths:[CGRect]=[CGRect(x:2,y:1,width:5,height:1.4),CGRect(x:6.3,y:2,width:1.4,height:5.2),CGRect(x:6.3,y:8.8,width:1.4,height:5.2),CGRect(x:2,y:13.8,width:5,height:1.4),CGRect(x:0.7,y:8.8,width:1.4,height:5.2),CGRect(x:0.7,y:2,width:1.4,height:5.2),CGRect(x:2,y:7.3,width:5,height:1.4)]
            for (i,rect) in paths.enumerated(){context.fill(Path(roundedRect:rect,cornerRadius:0.4),with:.color(masks[max(0,min(9,digit))]&(1<<i)>0 ? Color(red:1,green:0.12,blue:0.09):Color(red:0.19,green:0.045,blue:0.035)))}
        }.frame(width:9,height:16)
    }
}

struct RackKnobFace:View {
    let style:Int
    let fraction:Double
    let width:CGFloat
    let height:CGFloat
    var body:some View{
        let angle = -135+270*fraction
        let large=width>20, red=style==12521, white=style==12507 || style==12522, selector=style==12525
        let diameter:CGFloat=large ? 24:min(width,height)-2
        ZStack{
            Circle().fill(LinearGradient(colors:selector ? [Color(white:0.24),Color(white:0.07)]:red ? [Color(red:0.96,green:0.2,blue:0.14),Color(red:0.5,green:0.05,blue:0.03)]:white ? [Color(white:0.98),Color(white:0.62)]:[Color(white:0.55),Color(white:0.20)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .overlay(Circle().stroke(Color.black.opacity(0.8),lineWidth:large ? 1:0.5)).frame(width:diameter,height:diameter)
            if large{Circle().stroke(Color.white.opacity(0.65),lineWidth:0.8).frame(width:diameter-4,height:diameter-4)}
            Capsule().fill(selector || style==12565 ? Color(red:0.95,green:0.3,blue:0.13):white ? .black:Color(white:0.05))
                .frame(width:large ? 1.8:1.1,height:diameter*0.3).offset(y:-diameter*0.27).rotationEffect(.degrees(angle))
        }.frame(width:width,height:height)
    }
}

private struct RackArtworkPreviewKey:EnvironmentKey {static let defaultValue=false}
extension EnvironmentValues {
    var rackArtworkPreview:Bool {
        get{self[RackArtworkPreviewKey.self]}
        set{self[RackArtworkPreviewKey.self]=newValue}
    }
}
