import SwiftUI
import AppKit
import RebornModel

// Original rack coordinates, crisp cached faceplates and live controls.
private struct Artwork:View {
    @Environment(\.rackSkin) private var skin
    let id:Int
    var body:some View{if let image=skin?.plate(id) ?? RackDrawing.plate(id){Image(nsImage:image).interpolation(.high)}}
}
struct OriginalNumber:View {
    @Environment(\.rackSkin) private var skin
    let value:Int
    var digits=2
    var body:some View {
        HStack(spacing:0){ForEach(0..<digits,id:\.self){position in
            let divisor=Int(pow(10,Double(digits-position-1)))
            if let image=skin?.sprite(12015,index:max(0,value)/divisor%10+1,width:9,height:16,stride:10){Image(nsImage:image).interpolation(.high)}else{RackSevenSegment(digit:max(0,value)/divisor%10)}
        }}.background(.black).accessibilityElement(children:.ignore).accessibilityLabel("\(value)")
    }
}
private struct OriginalKnob:View {
    @Environment(\.rackArtworkPreview) private var preview
    @Binding var value:Double
    var range:ClosedRange<Double> = 0...127
    var title:String
    var sheet=12507
    var width:CGFloat=30
    var height:CGFloat=30
    var frames=54
    var stride:CGFloat?=31
    var resetValue:Double?=nil
    @Environment(\.rackSkin) private var skin
    @State private var editing=false
    private var fraction:Double{min(1,max(0,(value-range.lowerBound)/(range.upperBound-range.lowerBound)))}
    private var skinKnob:NSImage?{skin?.sprite(sheet==0 ? 12565:sheet,index:Int((fraction*Double(frames-1)).rounded()),width:width,height:height,stride:stride ?? width)}
    @ViewBuilder private var face:some View{
        if let image=skinKnob{Image(nsImage:image).interpolation(.high)}
        else{RackKnobFace(style:sheet,fraction:fraction,width:width,height:height)}
    }
    var body:some View {
        face
            .contentShape(Rectangle()).allowsHitTesting(true)
            .overlay{if !preview{RackControlInput(value:$value,range:range,reset:resetValue ?? (range.lowerBound+range.upperBound)/2){editing=$0}}}
            .overlay(alignment:.top){if editing{Text(value.formatted(.number.precision(.fractionLength(1)))).font(.system(size:7,weight:.bold,design:.monospaced)).foregroundStyle(.white).padding(3).background(Color(white:0.1),in:RoundedRectangle(cornerRadius:2)).offset(y:-15).allowsHitTesting(false)}}
            .accessibilityElement().accessibilityLabel(title).accessibilityValue("\(value)")
            .accessibilityAdjustableAction{direction in value=min(range.upperBound,max(range.lowerBound,value+(direction == .increment ? 1:-1)*(range.upperBound-range.lowerBound)/127))}
            .help("\(title): \(value.formatted(.number.precision(.fractionLength(1)))) · ziehen, Mausrad, ⇧ fein · Doppelklick: zurücksetzen")
    }
}
private struct Hotspot:View {
    let title:String
    let action:()->Void
    var body:some View {
        Button(action:action){Color.clear.contentShape(Rectangle())}.buttonStyle(.plain).accessibilityLabel(title).help(title)
    }
}
private struct TinyLight:View {
    let on:Bool
    var color:Color = .red
    var body:some View{Circle().fill(on ? color:Color(white:0.15)).frame(width:4,height:4).allowsHitTesting(false)}
}
private struct OriginalPattern:View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var studio:Studio
    let device:Int
    @State private var bassCopy:BassPattern?
    @State private var drumCopy:DrumPattern?
    private var selected:Int{device<2 ? studio.song.bass[device].selectedPattern:studio.song.drums[device-2].selectedPattern}
    private var length:Int{device<2 ? studio.song.bass[device].length:studio.song.drums[device-2].length}
    private var enabled:Bool{device<2 ? studio.song.bass[device].enabled:studio.song.drums[device-2].enabled}
    private var shuffled:Bool{device<2 ? studio.song.bass[device].shuffled:studio.song.drums[device-2].shuffled}
    private func select(_ pattern:Int){studio.changeController(device+1,1,pattern){if device<2{studio.song.bass[device].selectedPattern=pattern}else{studio.song.drums[device-2].selectedPattern=pattern}}}
    var body:some View {
        ZStack(alignment:.topLeading){
            Artwork(id:12058)
            TinyLight(on:enabled,color:.green).position(x:12,y:10)
            Hotspot(title:"Gerät an/aus"){studio.changeController(device+1,0,enabled ? 0:1){if device<2{studio.song.bass[device].enabled.toggle()}else{studio.song.drums[device-2].enabled.toggle()}}}.frame(width:64,height:16).position(x:35,y:10)
            ForEach(0..<8,id:\.self){n in
                let x=CGFloat(12+n%4*15),y=CGFloat(32+n/4*15)
                RoundedRectangle(cornerRadius:2).stroke(selected%8==n ? Color.red:.clear,lineWidth:2).frame(width:12,height:12).position(x:x,y:y)
                Hotspot(title:"Pattern \(n+1)"){select(selected/8*8+n)}.frame(width:14,height:14).position(x:x,y:y)
            }
            ForEach(0..<4,id:\.self){bank in
                RoundedRectangle(cornerRadius:2).stroke(selected/8==bank ? Color.red:.clear,lineWidth:2).frame(width:12,height:12).position(x:CGFloat(12+bank*15),y:75)
                Hotspot(title:"Bank \(["A","B","C","D"][bank])"){select(bank*8+selected%8)}.frame(width:14,height:14).position(x:CGFloat(12+bank*15),y:75)
            }
            Rectangle().fill(shuffled ? .gray:.black).frame(width:9,height:8).position(x:12,y:103)
            Hotspot(title:"Shuffle"){if device<2{studio.song.bass[device].shuffled.toggle()}else{studio.song.drums[device-2].shuffled.toggle()}}.frame(width:15,height:15).position(x:12,y:103)
            OriginalNumber(value:length).position(x:45,y:103)
            Hotspot(title:"Länge erhöhen"){if device<2{studio.song.bass[device].length=min(16,length+1)}else{studio.song.drums[device-2].length=min(16,length+1)}}.frame(width:10,height:8).position(x:62,y:99)
            Hotspot(title:"Länge verringern"){if device<2{studio.song.bass[device].length=max(1,length-1)}else{studio.song.drums[device-2].length=max(1,length-1)}}.frame(width:10,height:8).position(x:62,y:107)
        }.frame(width:70,height:115).contextMenu{
            Button("Presets"){studio.presetDevice=device;openWindow(id:"presets")}
            Button("Kopieren"){if device<2{bassCopy=studio.song.bass[device].patterns[selected]}else{drumCopy=studio.song.drums[device-2].patterns[selected]}}
            Button("Einfügen"){if device<2,let copy=bassCopy{studio.song.bass[device].patterns[selected]=copy}else if device>=2,let copy=drumCopy{studio.song.drums[device-2].patterns[selected]=copy}}.disabled(device<2 ? bassCopy==nil:drumCopy==nil)
            Button("Leeren"){if device<2{studio.song.bass[device].patterns[selected]=BassPattern()}else{studio.song.drums[device-2].patterns[selected]=DrumPattern()}}
        }
    }
}
private struct OriginalBass:View {
    @ObservedObject var studio:Studio
    let device:Int
    @State private var selected=0
    @State private var pitchMode=true
    private var step:BassStep{studio.song.bass[device].steps[selected]}
    private func transpose(_ amount:Int){studio.song.bass[device].steps[selected].note=min(95,max(0,step.note+amount))}
    var body:some View {
        ZStack(alignment:.topLeading){
            Artwork(id:12500)
            ForEach(0..<6,id:\.self){i in
                OriginalKnob(value:studio.live($studio.song.bass[device].controls[i],device:device+1,parameter:i+2),title:["Tune","Cutoff","Resonance","Envelope","Decay","Accent"][i],resetValue:[64,64,48,64,64,64][i]).position(x:CGFloat([86,119,152,186,220,254][i]),y:27)
            }
            Rectangle().fill(Color(white:0.6)).frame(width:14,height:9).position(x:31,y:15)
            Rectangle().fill(.black).frame(width:5,height:8).position(x:studio.song.bass[device].controls[6]>0 ? 36:27,y:15)
            Hotspot(title:"Sägezahn / Rechteck"){let v=studio.song.bass[device].controls[6]>0 ? 0.0:1.0;studio.changeController(device+1,8,Int(v)){studio.song.bass[device].controls[6]=v}}.frame(width:50,height:25).position(x:35,y:19)
            EditableRackNumber(value:Binding(get:{Double(selected+1)},set:{selected=Int($0)-1}),range:1...Double(studio.song.bass[device].length),title:"Schritt").position(x:338,y:33)
            TinyLight(on:pitchMode).position(x:27,y:73)
            Hotspot(title:"Pitch mode"){pitchMode.toggle()}.frame(width:26,height:12).position(x:27,y:79)
            Hotspot(title:"Note löschen"){studio.song.bass[device].steps[selected].enabled=false}.frame(width:26,height:12).position(x:27,y:101)
            ForEach(0..<13,id:\.self){key in
                let xs=[55,66,77,88,98,119,130,141,152,162,174,183,203]
                let black=[1,3,6,8,10].contains(key)
                TinyLight(on:step.enabled && key<12 && step.note%12==key).position(x:CGFloat(xs[key]),y:black ? 56:86)
                Hotspot(title:"Note \(["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B","C"][key])"){
                    studio.song.bass[device].steps[selected].note=min(95,step.note/12*12+key);studio.song.bass[device].steps[selected].enabled=true
                }.frame(width:13,height:black ? 27:23).position(x:CGFloat(xs[key]),y:black ? 65:98)
            }
            Hotspot(title:"Oktave tiefer"){transpose(-12)}.frame(width:18,height:16).position(x:229,y:97)
            Hotspot(title:"Oktave höher"){transpose(12)}.frame(width:18,height:16).position(x:253,y:97)
            TinyLight(on:step.accent).position(x:278,y:83)
            Hotspot(title:"Accent"){studio.song.bass[device].steps[selected].accent.toggle()}.frame(width:19,height:20).position(x:278,y:97)
            TinyLight(on:step.slide).position(x:304,y:83)
            Hotspot(title:"Slide"){studio.song.bass[device].steps[selected].slide.toggle()}.frame(width:19,height:20).position(x:304,y:97)
            Hotspot(title:"Note / Pause"){studio.song.bass[device].steps[selected].enabled.toggle()}.frame(width:38,height:17).position(x:237,y:66)
            Hotspot(title:"Accent / Slide bearbeiten"){pitchMode=false}.frame(width:39,height:17).position(x:291,y:66)
            Hotspot(title:"Voriger Schritt"){selected=(selected+studio.song.bass[device].length-1)%studio.song.bass[device].length}.frame(width:27,height:13).position(x:338,y:68)
            Hotspot(title:"Nächster Schritt"){selected=(selected+1)%studio.song.bass[device].length}.frame(width:28,height:18).position(x:338,y:98)
        }.frame(width:366,height:115)
        .onChange(of:studio.song.bass[device].length){length in selected=min(selected,length-1)}
        .contextMenu{
            Menu("Schritt"){ForEach(0..<16,id:\.self){s in Button("\(s+1)"){selected=s}}}
            Button("Zufall"){for s in 0..<16{studio.song.bass[device].steps[s]=BassStep(note:[36,39,41,43,46,48,51,55,60].randomElement()!,enabled:Bool.random(),accent:Bool.random(),slide:Int.random(in:0..<4)==0)}}
        }
    }
}
private struct OriginalDrums:View {
    @ObservedObject var studio:Studio
    let device:Int
    @State private var lane=0
    @State private var accent=false
    private var pattern:Int{studio.song.drums[device].selectedPattern}
    private var names:[String]{device==0 ? ["BD","SD","LT","MT","HT","RS","CP","CB","CY","OH","CH"]:["BD","SD","LT","MT","HT","RS","CP","CH","OH","CC","RC"]}
    private func control(_ p:Int)->Binding<Double>{studio.drumControl(device:device,parameter:p)}
    private func hit(_ step:Int)->Bool{accent ? studio.song.drums[device].patterns[pattern].accents[step]:studio.song.drums[device].patterns[pattern].hits[lane].steps[step]}
    private func toggle(_ step:Int){if accent{studio.song.drums[device].patterns[pattern].accents[step].toggle()}else{studio.song.drums[device].patterns[pattern].hits[lane].steps[step].toggle()}}
    var body:some View {
        ZStack(alignment:.topLeading){
            Artwork(id:device==0 ? 12520:12564)
            if device==0 {eightControls}else{nineControls}
            ForEach(0..<16,id:\.self){s in
                let x=device==0 ? CGFloat(21+s*16):CGFloat(36+s*21)
                TinyLight(on:hit(s) || (studio.playing && studio.deviceSteps[device+2]==s),color:studio.playing && studio.deviceSteps[device+2]==s ? .green:.red).position(x:x,y:device==0 ? 94:91)
                Hotspot(title:"\(accent ? "AC":names[lane]), Schritt \(s+1)"){toggle(s)}.frame(width:device==0 ? 15:19,height:25).position(x:x,y:101).contextMenu{
                    if device==1{Button("Starker Anschlag"){studio.song.drums[device].patterns[pattern].hits[lane].strong[s].toggle()};Button("Flam"){studio.song.drums[device].patterns[pattern].hits[lane].flam[s].toggle()}}
                }
            }
        }.frame(width:366,height:115).contextMenu{
            Menu("Stimme"){Button("AC"){accent=true};ForEach(0..<11,id:\.self){v in Button(names[v]){lane=v;accent=false}}}
            Menu("Sample"){Button("Original"){studio.song.drums[device].voices[lane].sample = -1};ForEach(0..<46,id:\.self){s in Button("Sample \(s+1)"){studio.song.drums[device].voices[lane].sample=s}}}
        }
    }
    private var eightControls:some View {
        Group{
            OriginalKnob(value:control(2),title:"Accent",sheet:12521,width:13,height:13,frames:36,stride:14,resetValue:DrumDefinitions.defaults(device)[2]).position(x:18,y:15)
            Hotspot(title:"Accent bearbeiten"){accent=true}.frame(width:19,height:13).position(x:20,y:78)
            ForEach(0..<11,id:\.self){v in
                let x=CGFloat(44+v*22)
                OriginalKnob(value:control(DrumDefinitions.levels[0][v]),title:"\(names[v]) Level",sheet:12521,width:13,height:13,frames:36,stride:14,resetValue:DrumDefinitions.defaults(device)[DrumDefinitions.levels[0][v]]).position(x:x,y:15)
                Rectangle().fill(!accent && lane==v ? Color.orange:.clear).frame(width:16,height:1).position(x:x,y:84)
                Hotspot(title:names[v]){lane=v;accent=false}.frame(width:21,height:14).position(x:x,y:78)
                ForEach(Array(DrumDefinitions.parameters[0][v].enumerated()),id:\.offset){item in
                    let p=item.element, y:CGFloat=item.offset==0 && !DrumDefinitions.isSwitch(0,item.element.0) && v != 9 ? 37:57
                    if DrumDefinitions.isSwitch(0,p.0){Rectangle().fill(.black).frame(width:9,height:3).position(x:x,y:y+(control(p.0).wrappedValue>0 ? -2:2));Hotspot(title:p.1){control(p.0).wrappedValue=control(p.0).wrappedValue>0 ? 0:1}.frame(width:19,height:14).position(x:x,y:y)}
                    else{OriginalKnob(value:control(p.0),title:p.1,sheet:12522,width:13,height:13,frames:36,stride:14,resetValue:DrumDefinitions.defaults(device)[p.0]).position(x:x,y:y)}
                }
            }
            OriginalKnob(value:Binding(get:{Double(lane)*127/10},set:{lane=min(10,max(0,Int(($0*10/127).rounded())));accent=false}),title:"Instrument",sheet:12525,width:30,height:31,frames:12,stride:30,resetValue:0).position(x:320,y:62)
        }
    }
    private var nineControls:some View {
        Group{
            OriginalKnob(value:control(2),title:"Accent",sheet:12565,width:13,height:12,frames:38,stride:14,resetValue:DrumDefinitions.defaults(device)[2]).position(x:15,y:34)
            OriginalKnob(value:control(29),title:"Flam",sheet:12565,width:13,height:12,frames:38,stride:14,resetValue:DrumDefinitions.defaults(device)[29]).position(x:15,y:82)
            Hotspot(title:"Accent bearbeiten"){accent=true}.frame(width:20,height:16).position(x:15,y:9)
            ForEach(0..<11,id:\.self){v in
                let x=CGFloat([35,78,120,163,205,247,268,289,310,331,352][v])
                OriginalKnob(value:control(DrumDefinitions.levels[1][v]),title:"\(names[v]) Level",sheet:12565,width:13,height:12,frames:38,stride:14,resetValue:100).position(x:v<5 ? x+21:x,y:34)
                Rectangle().fill(!accent && lane==v ? Color.orange:.clear).frame(width:18,height:1).position(x:x,y:15)
                Hotspot(title:names[v]){lane=v;accent=false}.frame(width:20,height:12).position(x:x,y:9)
                ForEach(Array(DrumDefinitions.parameters[1][v].enumerated()),id:\.offset){item in
                    let p=item.element
                    let knobX:CGFloat=v<2 ? x+(item.offset==2 ? 21:0):v<5 && item.offset==1 ? x+10:x
                    let y:CGFloat=item.offset==0 && v<5 ? 34:59
                    OriginalKnob(value:control(p.0),title:p.1,sheet:12565,width:13,height:12,frames:38,stride:14,resetValue:DrumDefinitions.defaults(device)[p.0]).position(x:knobX,y:y)
                }
            }
        }
    }
}
private struct OriginalFader:View {
    @Environment(\.rackSkin) private var skin
    @Environment(\.rackArtworkPreview) private var preview
    @Binding var value:Double
    var title:String
    var range:ClosedRange<Double> = 0...1
    var height:CGFloat=46
    var resetValue:Double?=nil
    @State private var editing=false
    private var thumbOffset:CGFloat{CGFloat(0.5-(value-range.lowerBound)/(range.upperBound-range.lowerBound))*(height-4)}
    @ViewBuilder private var face:some View {
        if let track=skin?.image(12030),let thumb=skin?.image(12031){
            ZStack{Image(nsImage:track).interpolation(.high).scaleEffect(x:1,y:(height-4)/45);Image(nsImage:thumb).interpolation(.high).offset(y:thumbOffset)}
        }else{
            ZStack{
                Rectangle().fill(.black.opacity(0.7)).frame(width:2,height:height-4)
                ForEach(0..<8,id:\.self){tick in Rectangle().fill(Color(white:0.7)).frame(width:12,height:0.5).offset(y:CGFloat(tick)*(height-4)/7-(height-4)/2)}
                Rectangle().fill(LinearGradient(colors:[Color(white:0.7),Color(white:0.25)],startPoint:.top,endPoint:.bottom)).frame(width:13,height:5).overlay(Rectangle().fill(.black).frame(height:0.5)).offset(y:thumbOffset)
            }
        }
    }
    var body:some View{
        face.frame(width:15,height:height).contentShape(Rectangle())
        .overlay{if !preview{RackControlInput(value:$value,range:range,reset:resetValue ?? (range.upperBound==1 ? 100.0/127:64),relative:false){editing=$0}}}
        .overlay(alignment:.top){if editing{Text(value.formatted(.number.precision(.fractionLength(2)))).font(.system(size:7,weight:.bold,design:.monospaced)).foregroundStyle(.white).padding(3).background(Color(white:0.1)).offset(y:-13).allowsHitTesting(false)}}
        .accessibilityElement().accessibilityLabel(title).accessibilityValue("\(value)")
        .accessibilityAdjustableAction{d in value=min(range.upperBound,max(range.lowerBound,value+(d == .increment ? 1:-1)*(range.upperBound-range.lowerBound)/127))}
    }
}
private struct OriginalMixer:View {
    @ObservedObject var studio:Studio
    let device:Int
    private var level:Binding<Double>{device<2 ? studio.live($studio.song.bass[device].level,device:0,parameter:6+6*device,scale:1/127):studio.live($studio.song.drums[device-2].level,device:0,parameter:6+6*device,scale:1/127)}
    private var pan:Binding<Double>{device<2 ? studio.live($studio.song.bass[device].pan,device:0,parameter:7+6*device,scale:1/63.5,offset:-1):studio.live($studio.song.drums[device-2].pan,device:0,parameter:7+6*device,scale:1/63.5,offset:-1)}
    private func edit(_ action:(inout EffectSettings)->Void){var r=studio.song.effectiveRack;action(&r);studio.song.rack=r}
    var body:some View{
        ZStack(alignment:.topLeading){
            Artwork(id:12060)
            TinyLight(on:device<2 ? studio.song.bass[device].channelEnabled:studio.song.drums[device-2].channelEnabled,color:.green).position(x:14,y:10)
            Hotspot(title:"Mixerkanal an/aus"){if device<2{studio.song.bass[device].channelEnabled.toggle()}else{studio.song.drums[device-2].channelEnabled.toggle()}}.frame(width:60,height:15).position(x:35,y:10)
            OriginalKnob(value:pan,range:-1...1,title:"Pan",sheet:0,width:13,height:12,frames:38,stride:14).position(x:19,y:37)
            OriginalFader(value:level,title:"Level").position(x:19,y:83)
            OriginalKnob(value:Binding(get:{studio.liveValue(0,8+6*device) ?? studio.song.effectiveRack.sends[device]},set:{v in studio.changeController(0,8+6*device,Int(v.rounded())){edit{$0.sends[device]=v}}}),title:"Delay send",sheet:0,width:13,height:12,frames:38,stride:14,resetValue:0).position(x:51,y:95)
            TinyLight(on:studio.song.effectiveRack.distorted[device],color:.green).position(x:59,y:51)
            Hotspot(title:"Distortion an/aus"){let v = !studio.song.effectiveRack.distorted[device];studio.changeController(0,9+6*device,v ? 1:0){edit{$0.distorted[device]=v}}}.frame(width:24,height:13).position(x:54,y:51)
            TinyLight(on:studio.song.effectiveRack.pcfTarget==device+1,color:.green).position(x:59,y:68)
            Hotspot(title:"PCF zuweisen"){edit{$0.pcfTarget=$0.pcfTarget==device+1 ? 0:device+1}}.frame(width:24,height:13).position(x:54,y:68)
            TinyLight(on:studio.song.effectiveRack.compressorTarget==device+2,color:.green).position(x:59,y:83)
            Hotspot(title:"Kompressor zuweisen"){edit{$0.compressorTarget=$0.compressorTarget==device+2 ? 0:device+2}}.frame(width:24,height:13).position(x:54,y:83)
        }.frame(width:70,height:115)
    }
}
private struct OriginalEffects:View {
    @ObservedObject var studio:Studio
    private func control(_ effect:Int,_ parameter:Int)->Binding<Double>{
        Binding(get:{let r=studio.song.effectiveRack;return studio.liveValue([6,5,8,7][effect],parameter) ?? [r.distortion,r.delay,r.compressor,r.pcf][effect][parameter]},set:{v in studio.changeController([6,5,8,7][effect],parameter,Int(v.rounded())){var r=studio.song.effectiveRack;switch effect{case 0:r.distortion[parameter]=v;case 1:r.delay[parameter]=v;case 2:r.compressor[parameter]=v;default:r.pcf[parameter]=v};studio.song.rack=r}})
    }
    private func knob(_ effect:Int,_ p:Int,_ title:String)->some View{let defaults=EffectSettings();return OriginalKnob(value:control(effect,p),title:title,sheet:0,width:13,height:12,frames:38,stride:14,resetValue:[defaults.distortion,defaults.delay,defaults.compressor,defaults.pcf][effect][p])}
    private func toggle(_ effect:Int)->some View{Hotspot(title:"Effekt an/aus"){control(effect,0).wrappedValue=control(effect,0).wrappedValue>0 ? 0:1}}
    var body:some View{
        VStack(spacing:0){
            ZStack(alignment:.topLeading){
                Artwork(id:12061)
                OriginalFader(value:$studio.song.master,title:"Master",height:45).position(x:42,y:55)
                ForEach(0..<12,id:\.self){n in
                    let on=Double(studio.peak)>pow(10,Double(-n*3)/20)
                    Rectangle().fill(on ? (n<2 ? Color.red:Color.green):Color(white:0.12)).frame(width:4,height:2).position(x:23,y:CGFloat(34+n*3))
                    Rectangle().fill(on ? (n<2 ? Color.red:Color.green):Color(white:0.12)).frame(width:4,height:2).position(x:62,y:CGFloat(34+n*3))
                }
                TinyLight(on:studio.song.effectiveRack.compressorTarget==1,color:.green).position(x:62,y:88)
                Hotspot(title:"Kompressor auf Master"){var r=studio.song.effectiveRack;r.compressorTarget=r.compressorTarget==1 ? 0:1;studio.song.rack=r}.frame(width:30,height:12).position(x:46,y:88)
            }.frame(width:82,height:98)
            ZStack(alignment:.topLeading){
                Artwork(id:12064)
                toggle(3).frame(width:16,height:14).position(x:16,y:10)
                TinyLight(on:control(3,0).wrappedValue>0,color:.green).position(x:15,y:10)
                OriginalNumber(value:Int(control(3,4).wrappedValue)+1).position(x:20,y:32)
                Hotspot(title:"PCF Pattern +"){control(3,4).wrappedValue=Double((Int(control(3,4).wrappedValue)+1)%55)}.frame(width:12,height:10).position(x:34,y:27)
                Hotspot(title:"PCF Pattern −"){control(3,4).wrappedValue=Double((Int(control(3,4).wrappedValue)+54)%55)}.frame(width:12,height:10).position(x:34,y:37)
                Rectangle().fill(.black).frame(width:4,height:5).position(x:58,y:control(3,6).wrappedValue>0 ? 37:27)
                Hotspot(title:"Lowpass / Highpass"){control(3,6).wrappedValue=control(3,6).wrappedValue>0 ? 0:1}.frame(width:19,height:28).position(x:62,y:33)
                ForEach(0..<4,id:\.self){i in OriginalFader(value:control(3,[1,2,3,5][i]),title:["Frequency","Q","Amount","Decay"][i],range:0...127,height:42,resetValue:EffectSettings().pcf[[1,2,3,5][i]]).position(x:CGFloat(14+i*18),y:76)}
            }.frame(width:82,height:111)
            ZStack(alignment:.topLeading){
                Artwork(id:12063)
                toggle(1).frame(width:16,height:14).position(x:16,y:10)
                TinyLight(on:control(1,0).wrappedValue>0,color:.green).position(x:16,y:10)
                OriginalNumber(value:Int(control(1,1).wrappedValue)).position(x:18,y:32)
                Hotspot(title:"Delay Steps +"){control(1,1).wrappedValue=min(16,control(1,1).wrappedValue+1)}.frame(width:10,height:9).position(x:34,y:27)
                Hotspot(title:"Delay Steps −"){control(1,1).wrappedValue=max(1,control(1,1).wrappedValue-1)}.frame(width:10,height:9).position(x:34,y:37)
                Rectangle().fill(.black).frame(width:3,height:5).position(x:55,y:control(1,2).wrappedValue>0 ? 39:28)
                Hotspot(title:"Gerade / Triolen"){control(1,2).wrappedValue=control(1,2).wrappedValue>0 ? 0:1}.frame(width:22,height:23).position(x:61,y:33)
                knob(1,4,"Delay Pan").position(x:20,y:69);knob(1,3,"Feedback").position(x:61,y:69)
            }.frame(width:82,height:93)
            ZStack(alignment:.topLeading){
                Artwork(id:12065)
                toggle(0).frame(width:16,height:14).position(x:16,y:10)
                TinyLight(on:control(0,0).wrappedValue>0,color:.green).position(x:16,y:10)
                knob(0,1,"Amount").position(x:20,y:39);knob(0,2,"Shape").position(x:61,y:39)
            }.frame(width:82,height:65)
            ZStack(alignment:.topLeading){
                Artwork(id:12569)
                toggle(2).frame(width:16,height:14).position(x:16,y:10)
                TinyLight(on:control(2,0).wrappedValue>0,color:.green).position(x:16,y:10)
                knob(2,1,"Ratio").position(x:20,y:66);knob(2,2,"Threshold").position(x:61,y:66)
            }.frame(width:82,height:93)
        }.frame(width:82,height:460)
    }
}
private struct OriginalTransport:View {
    @ObservedObject var studio:Studio
    private var start:Int{(studio.song.loopStart ?? 0)/768+1}
    private var length:Int{max(1,((studio.song.loopEnd ?? 768)-(studio.song.loopStart ?? 0))/768)}
    private func loopStart(_ delta:Int){let tick=(min(130208,max(1,start+delta))-1)*768;studio.song.loopStart=tick;studio.song.loopEnd=max(tick+768,studio.song.loopEnd ?? 768)}
    private func loopLength(_ delta:Int){let from=studio.song.loopStart ?? 0;studio.song.loopEnd=from+min(max(1,length+delta),(100000000-from)/768)*768}
    var body:some View {
        ZStack(alignment:.topLeading){
            Artwork(id:12057)
            OriginalKnob(value:$studio.song.swing,range:0...0.45,title:"Shuffle",sheet:0,width:13,height:12,frames:38,stride:14,resetValue:0).position(x:21,y:26)
            EditableRackNumber(value:$studio.song.tempo,digits:3,range:20...300,title:"Tempo").disabled(studio.recording).position(x:58,y:34)
            Hotspot(title:"Tempo +"){studio.song.tempo=min(300,studio.song.tempo+1)}.frame(width:10,height:9).position(x:78,y:30).disabled(studio.recording)
            Hotspot(title:"Tempo −"){studio.song.tempo=max(20,studio.song.tempo-1)}.frame(width:10,height:9).position(x:78,y:39).disabled(studio.recording)
            TinyLight(on:studio.midiEnabled,color:.green).position(x:77,y:13)
            Hotspot(title:"MIDI"){studio.midiEnabled.toggle()}.frame(width:22,height:14).position(x:78,y:10)
            Hotspot(title:"Pattern mode"){studio.song.songMode=false}.frame(width:54,height:17).position(x:147,y:10).disabled(studio.recording)
            Hotspot(title:"Song mode"){studio.song.songMode=true}.frame(width:64,height:17).position(x:207,y:10).disabled(studio.recording)
            TinyLight(on:!(studio.song.songMode ?? false),color:.green).position(x:173,y:10)
            TinyLight(on:studio.song.songMode ?? false,color:.green).position(x:181,y:10)
            Hotspot(title:studio.playing ? "Wiedergabe stoppen · Leertaste":"Wiedergabe starten · Leertaste",action:studio.togglePlayback).frame(width:32,height:23).position(x:112,y:34).keyboardShortcut(.space,modifiers:[])
            Image(systemName:"play.fill").font(.system(size:10,weight:.bold)).foregroundStyle(studio.playing ? Color.green:Color(red:0.08,green:0.33,blue:0.13)).allowsHitTesting(false).position(x:112,y:34)
            Hotspot(title:"Stop"){if studio.recording{studio.toggleRecording()}else if studio.playing{studio.togglePlayback()}}.frame(width:30,height:23).position(x:143,y:34)
            Hotspot(title:"Ein Takt zurück"){studio.seek(studio.currentTick-768)}.frame(width:30,height:23).position(x:175,y:34).disabled(studio.recording)
            Hotspot(title:"Ein Takt weiter"){studio.seek(studio.currentTick+768)}.frame(width:30,height:23).position(x:207,y:34).disabled(studio.recording)
            Hotspot(title:"Aufnahme",action:studio.toggleRecording).frame(width:30,height:23).position(x:239,y:34)
            Circle().fill(studio.recording ? Color.red:Color(red:0.4,green:0.06,blue:0.06)).frame(width:5,height:5).allowsHitTesting(false).position(x:239,y:34)
            OriginalNumber(value:studio.currentTick/768+1,digits:3).position(x:284,y:35)
            Hotspot(title:"Zum Anfang"){studio.seek(0)}.frame(width:9,height:10).position(x:305,y:30).disabled(studio.recording)
            Hotspot(title:"Nächster Takt"){studio.seek(studio.currentTick+768)}.frame(width:9,height:10).position(x:305,y:39).disabled(studio.recording)
            TinyLight(on:studio.song.looping ?? false,color:.green).position(x:320,y:11)
            Hotspot(title:"Loop"){studio.song.looping = !(studio.song.looping ?? false)}.frame(width:34,height:18).position(x:352,y:9).disabled(studio.recording)
            EditableRackNumber(value:Binding(get:{Double(start)},set:{loopStart(Int($0)-start)}),digits:3,range:1...130208,title:"Loop Start").disabled(studio.recording).position(x:347,y:35)
            EditableRackNumber(value:Binding(get:{Double(length)},set:{loopLength(Int($0)-length)}),digits:3,range:1...130208,title:"Loop Length").disabled(studio.recording).position(x:389,y:35)
            Hotspot(title:"Loop Start +"){loopStart(1)}.frame(width:10,height:9).position(x:368,y:30).disabled(studio.recording)
            Hotspot(title:"Loop Start −"){loopStart(-1)}.frame(width:10,height:9).position(x:368,y:39).disabled(studio.recording)
            Hotspot(title:"Loop Length +"){loopLength(1)}.frame(width:10,height:9).position(x:410,y:30).disabled(studio.recording)
            Hotspot(title:"Loop Length −"){loopLength(-1)}.frame(width:10,height:9).position(x:410,y:39).disabled(studio.recording)
            LinearGradient(colors:[Color(red:0.25,green:0.31,blue:0.31),Color(red:0.15,green:0.22,blue:0.22)],startPoint:.top,endPoint:.bottom).frame(width:175,height:48).position(x:503,y:25)
            Text("Reborn²").font(.system(size:21,weight:.black,design:.rounded)).foregroundStyle(Color(white:0.72)).shadow(color:.black,radius:0,x:1,y:1).position(x:505,y:24).allowsHitTesting(false)
        }.frame(width:592,height:50).contextMenu{
            Button("Song öffnen",action:studio.load);Button("Song sichern",action:studio.save);Button("ReBirth-Song (.rbs)",action:studio.saveRBS);Button("WAV exportieren",action:studio.exportAudio)
            Menu("Songs"){ForEach(studio.bundledSongs,id:\.self){url in Button(url.deletingPathExtension().lastPathComponent){studio.openSong(url)}}}
            Menu("Mods"){Button("Reborn² Standard"){studio.selectMod(nil)};ForEach(studio.availableMods,id:\.name){mod in Menu(mod.name){Button("Klänge laden"){studio.selectMod(mod)};Button("Demo öffnen"){studio.selectMod(mod,demo:true)}}}}
            Toggle("303: hohe Qualität",isOn:Binding(get:{studio.song.highQuality ?? true},set:{studio.song.highQuality=$0})).disabled(studio.recording || studio.playing)
        }
    }
}
struct OriginalRack:View {
    @ObservedObject var studio:Studio
    var body:some View{
        VStack(spacing:0){
            OriginalTransport(studio:studio)
            HStack(spacing:0){
                VStack(spacing:0){ForEach(0..<4,id:\.self){d in
                    HStack(spacing:0){
                        OriginalPattern(studio:studio,device:d)
                        if d<2{OriginalBass(studio:studio,device:d)}else{OriginalDrums(studio:studio,device:d-2)}
                        OriginalMixer(studio:studio,device:d)
                    }
                }}
                OriginalEffects(studio:studio)
            }.padding(.horizontal,2)
        }.frame(width:592,height:510).background(Color(white:0.2)).controlSize(.mini)
    }
}
