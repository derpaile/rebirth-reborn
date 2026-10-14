import Foundation

public struct RecordedNote:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var tick:Int,device:Int,note:Int,velocity:Int,duration:Int
    public init(tick:Int,device:Int,note:Int,velocity:Int,duration:Int){self.tick=tick;self.device=device;self.note=note;self.velocity=velocity;self.duration=duration}
    public var valid:Bool{(0...100_000_000).contains(tick)&&(0...3).contains(device)&&(0...(device<2 ? 95:10)).contains(note)&&(1...127).contains(velocity)&&(1...100_000_000).contains(duration)&&tick+duration<=100_000_001}
}
public struct ControllerTarget:Codable,Hashable,Identifiable {
    public var device:Int,parameter:Int
    public init(_ device:Int,_ parameter:Int){self.device=device;self.parameter=parameter}
    public var id:String{"\(device):\(parameter)"}
    public var range:ClosedRange<Int>{
        if device==0 {if parameter==1{return 0...5};if parameter==2{return 0...4};if (parameter-9)%6==0{return 0...1}}
        if (1...4).contains(device){if parameter==0{return 0...1};if parameter==1{return 0...31}}
        if device<3 && parameter==8{return 0...1}
        if device>=5 && parameter==0{return 0...1}
        if device==5 && parameter==1{return 1...16}
        if device==5 && parameter==2 || device==7 && parameter==6{return 0...1}
        if device==7 && parameter==4{return 0...54}
        if device==3 && [11,14,17,19,21].contains(parameter){return 0...1}
        return 0...127
    }
    public var label:String{
        guard valid else{return "Gerät \(device) · Regler \(parameter)"}
        let devices=["Mix","303 · 1","303 · 2","808","909","Delay","Distortion","PCF","Compressor"]
        var name="Regler \(parameter)"
        if device==0 {
            if parameter==1{name="Compressor-Ziel"}else if parameter==2{name="PCF-Ziel"}else{let channel=(parameter-6)/6;name=["303 · 1","303 · 2","808","909"][max(0,min(3,channel))]+" "+["Level","Pan","Delay","Dist"][max(0,min(3,(parameter-6)%6))]}
        }else if device<5 {
            if parameter==0{name="An/Aus"}else if parameter==1{name="Pattern"}else if device<3{name=["Tune","Cutoff","Resonance","Env Mod","Decay","Accent","Waveform"][parameter-2]}else if parameter==2{name="Accent"}else if parameter==29{name="Flam"}else{
                let machine=device-3,voices=machine==0 ? ["BD","SD","LT","MT","HT","RS","CP","CB","CY","OH","CH"]:["BD","SD","LT","MT","HT","RS","CP","CH","OH","CC","RC"]
                if let lane=DrumDefinitions.levels[machine].firstIndex(of:parameter){name=(machine==1 && parameter==22 ? "CH/OH":voices[lane])+" Level"}
                else{for lane in 0..<11{if let p=DrumDefinitions.parameters[machine][lane].first(where:{$0.0==parameter}){name=voices[lane]+" "+p.1;break}}}
            }
        }else{name=[5:["An/Aus","Steps","Straight","Feedback","Pan"],6:["An/Aus","Amount","Shape"],7:["An/Aus","Freq","Q","Amount","Pattern","Decay","Lowpass"],8:["An/Aus","Ratio","Threshold"]][device]?[parameter] ?? name}
        return devices[max(0,min(8,device))]+" · "+name
    }
    public static let all:[ControllerTarget] = {
        var targets=[ControllerTarget(0,1),ControllerTarget(0,2)]
        for d in 0..<4{for p in 6+6*d...9+6*d{targets.append(ControllerTarget(0,p))}}
        for d in 1...8{for p in 0..<(d<3 ? 9:d==3 ? 29:d==4 ? 30:d==5 ? 5:d==7 ? 7:3){targets.append(ControllerTarget(d,p))}}
        return targets
    }()
    public var valid:Bool{Self.all.contains(self)}
}
public struct MIDILearnedControl:Codable,Identifiable,Equatable {
    public var id=UUID(),source:Int32,channel:Int,cc:Int,target:ControllerTarget
    public init(source:Int32,channel:Int,cc:Int,target:ControllerTarget){self.source=source;self.channel=channel;self.cc=cc;self.target=target}
    public var valid:Bool{(0...15).contains(channel)&&(0...127).contains(cc)&&target.valid}
}
public struct MIDIClockTracker {
    private var last:Double?,intervals=[Double]()
    public init(){}
    public mutating func reset(){last=nil;intervals=[]}
    public mutating func pulse(at seconds:Double)->Double?{
        defer{last=seconds}
        guard let before=last,seconds>before else{return nil}
        let interval=seconds-before
        guard interval>0.002,interval<0.5 else{intervals=[];return nil}
        intervals.append(interval);if intervals.count>24{intervals.removeFirst()}
        guard intervals.count>=6 else{return nil}
        let average=intervals.reduce(0,+)/Double(intervals.count)
        return min(300,max(30,60/(24*average)))
    }
}
public struct SongHistory {
    public struct Entry {public let song:Song,label:String}
    public private(set) var undoEntries=[Entry](),redoEntries=[Entry]()
    private var lastTime=0.0,lastKey=""
    public var canUndo:Bool{!undoEntries.isEmpty};public var canRedo:Bool{!redoEntries.isEmpty}
    public init(){}
    public mutating func record(_ before:Song,after:Song,label:String="Bearbeiten",key:String="",at time:Double=Date.timeIntervalSinceReferenceDate){
        guard before != after else{return}
        if key.isEmpty || key != lastKey || time-lastTime>0.35 || undoEntries.isEmpty{undoEntries.append(Entry(song:before,label:label));if undoEntries.count>64{undoEntries.removeFirst()}}
        redoEntries=[];lastTime=time;lastKey=key
    }
    public mutating func undo(_ current:Song)->Song?{guard let entry=undoEntries.popLast() else{return nil};redoEntries.append(Entry(song:current,label:entry.label));lastKey="";return entry.song}
    public mutating func redo(_ current:Song)->Song?{guard let entry=redoEntries.popLast() else{return nil};undoEntries.append(Entry(song:current,label:entry.label));lastKey="";return entry.song}
}
public enum PresetKind:String,Codable,CaseIterable,Identifiable {
    case bassSound,drumKit,effects,bassPattern,drumPattern,rack
    public var id:String{rawValue}
    public var title:String{switch self{case .bassSound:return "303-Klang";case .drumKit:return "Drumkit";case .effects:return "Effekte";case .bassPattern:return "303-Pattern";case .drumPattern:return "Drum-Pattern";case .rack:return "Ganzes Rack"}}
}
public struct RebirthPreset:Codable,Identifiable,Equatable {
    public var id=UUID(),name:String,kind:PresetKind,created=Date(),factory=false
    public var bass:BassTrack?,drum:DrumTrack?,effect:EffectSettings?,bassPattern:BassPattern?,drumPattern:DrumPattern?,song:Song?,modName:String?,modData:Data?
    public var drumDevice:Int?
    public init(name:String,kind:PresetKind){self.name=name;self.kind=kind}
    public var valid:Bool {
        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,name.count<=100,(modData?.count ?? 0)<=32*1024*1024 else{return false}
        switch kind{case .bassSound:return bass?.valid==true;case .drumKit:return [0,1].contains(drumDevice ?? -1) && drum?.valid(drumDevice ?? 0)==true;case .effects:return effect?.valid==true;case .bassPattern:return bassPattern?.valid==true;case .drumPattern:return drumPattern?.valid==true;case .rack:return song?.valid==true}
    }
    public static var builtIn:[RebirthPreset]{
        var list=[RebirthPreset]()
        for (name,controls) in [("Init 303",[64.0,64,48,64,64,64,0]),("Acid",[64,75,100,95,48,100,0]),("Deep Bass",[64,38,30,45,90,32,0]),("Square Bass",[64,62,60,60,65,70,1])]{var preset=RebirthPreset(name:name,kind:.bassSound);var bass=BassTrack();bass.controls=controls;preset.bass=bass;preset.factory=true;list.append(preset)}
        for d in 0..<2{var kit=RebirthPreset(name:d==0 ? "Original 808":"Original 909",kind:.drumKit);kit.drum=DrumTrack(device:d);kit.drumDevice=d;kit.modName="Reborn Standard";kit.factory=true;list.append(kit)}
        for (name,send) in [("Dry",0.0),("Acid Echo",75.0)]{var effect=RebirthPreset(name:name,kind:.effects);var rack=EffectSettings();rack.sends=[send,send,0,0];effect.effect=rack;effect.factory=true;list.append(effect)}
        var bass=RebirthPreset(name:"Acid Sequence",kind:.bassPattern);bass.bassPattern=Song.demo().bass[0].patterns[0];bass.factory=true;list.append(bass)
        for (name,spacing) in [("Four on the Floor",4),("Half Time",8)]{var beat=RebirthPreset(name:name,kind:.drumPattern);var p=DrumPattern();for s in stride(from:0,to:16,by:spacing){p.hits[0].steps[s]=true};for s in [4,12]{p.hits[1].steps[s]=true};for s in stride(from:2,to:16,by:4){p.hits[7].steps[s]=true};beat.drumPattern=p;beat.factory=true;list.append(beat)}
        return list
    }
}
