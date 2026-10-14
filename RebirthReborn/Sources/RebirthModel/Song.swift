import Foundation

public struct BassStep: Codable, Equatable {
    public var note:Int,enabled:Bool,accent:Bool,slide:Bool
    public init(note:Int=48,enabled:Bool=false,accent:Bool=false,slide:Bool=false){self.note=note;self.enabled=enabled;self.accent=accent;self.slide=slide}
}
public struct BassPattern: Codable, Equatable {
    public var length=16,shuffled=true
    public var steps=Array(repeating:BassStep(),count:16)
    public init(){}
    public var valid:Bool {(1...16).contains(length)&&steps.count==16&&steps.allSatisfy{(0...95).contains($0.note)}}
}
public struct BassTrack: Codable, Equatable {
    public var controls:[Double]=[64,64,48,64,64,64,0]
    public var level=100.0/127,pan=0.0
    public var enabled=true,channelEnabled=true
    public var selectedPattern=0
    public var patterns=Array(repeating:BassPattern(),count:32)
    public var steps:[BassStep]{get{patterns[selectedPattern].steps}set{patterns[selectedPattern].steps=newValue}}
    public var length:Int{get{patterns[selectedPattern].length}set{patterns[selectedPattern].length=newValue}}
    public var shuffled:Bool{get{patterns[selectedPattern].shuffled}set{patterns[selectedPattern].shuffled=newValue}}
    public init(){}
    enum CodingKeys:String,CodingKey {case controls,level,pan,enabled,channelEnabled,selectedPattern,patterns,steps}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        controls=try c.decode([Double].self,forKey:.controls);level=try c.decode(Double.self,forKey:.level);pan=try c.decode(Double.self,forKey:.pan)
        enabled=try c.decodeIfPresent(Bool.self,forKey:.enabled) ?? true;channelEnabled=try c.decodeIfPresent(Bool.self,forKey:.channelEnabled) ?? true
        selectedPattern=try c.decodeIfPresent(Int.self,forKey:.selectedPattern) ?? 0
        if let banks=try c.decodeIfPresent([BassPattern].self,forKey:.patterns){patterns=banks}else{patterns[0].steps=try c.decode([BassStep].self,forKey:.steps)}
    }
    public func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:CodingKeys.self)
        try c.encode(controls,forKey:.controls);try c.encode(level,forKey:.level);try c.encode(pan,forKey:.pan);try c.encode(enabled,forKey:.enabled);try c.encode(channelEnabled,forKey:.channelEnabled);try c.encode(selectedPattern,forKey:.selectedPattern);try c.encode(patterns,forKey:.patterns)
    }
    public var valid:Bool {(0...31).contains(selectedPattern)&&patterns.count==32&&patterns.allSatisfy(\.valid)&&controls.count==7&&controls.allSatisfy{$0.isFinite&&(0...127).contains($0)}&&(0...1).contains(level)&&(-1...1).contains(pan)}
}
public struct DrumLane: Codable, Equatable {
    public var sample = -1
    public var level=100.0/127
    public var steps=Array(repeating:false,count:16)
    public var strongSteps:[Bool]?=Array(repeating:false,count:16)
    public var flamSteps:[Bool]?=Array(repeating:false,count:16)
    public init(){}
}
public struct DrumVoice: Codable,Equatable {
    public var sample = -1
    public var level=100.0/127
    public init(){}
}
public struct DrumHits:Codable,Equatable {
    public var steps=Array(repeating:false,count:16)
    public var strong=Array(repeating:false,count:16)
    public var flam=Array(repeating:false,count:16)
    public init(){}
}
public struct DrumPattern:Codable,Equatable {
    public var length=16,shuffled=true
    public var hits=Array(repeating:DrumHits(),count:11)
    public var accents=Array(repeating:false,count:16)
    public init(){}
    public var valid:Bool {(1...16).contains(length)&&accents.count==16&&hits.count==11&&hits.allSatisfy{$0.steps.count==16&&$0.strong.count==16&&$0.flam.count==16}}
}
public struct DrumTrack:Codable,Equatable {
    public var level=100.0/127,pan=0.0
    public var enabled=true,channelEnabled=true
    public var controls:[Double]?
    public var selectedPattern=0
    public var voices=Array(repeating:DrumVoice(),count:11)
    public var patterns=Array(repeating:DrumPattern(),count:32)
    public var length:Int{get{patterns[selectedPattern].length}set{patterns[selectedPattern].length=newValue}}
    public var shuffled:Bool{get{patterns[selectedPattern].shuffled}set{patterns[selectedPattern].shuffled=newValue}}
    public var accentSteps:[Bool]?{get{patterns[selectedPattern].accents}set{patterns[selectedPattern].accents=newValue ?? Array(repeating:false,count:16)}}
    public var lanes:[DrumLane] {
        get{(0..<11).map{i in var lane=DrumLane();lane.sample=voices[i].sample;lane.level=voices[i].level;let hit=patterns[selectedPattern].hits[i];lane.steps=hit.steps;lane.strongSteps=hit.strong;lane.flamSteps=hit.flam;return lane}}
        set{for i in 0..<min(11,newValue.count){voices[i].sample=newValue[i].sample;voices[i].level=newValue[i].level;patterns[selectedPattern].hits[i].steps=newValue[i].steps;patterns[selectedPattern].hits[i].strong=newValue[i].strongSteps ?? Array(repeating:false,count:16);patterns[selectedPattern].hits[i].flam=newValue[i].flamSteps ?? Array(repeating:false,count:16)}}
    }
    public init(device:Int=0){controls=DrumDefinitions.defaults(device)}
    enum CodingKeys:String,CodingKey {case level,pan,enabled,channelEnabled,controls,selectedPattern,voices,patterns,lanes,accentSteps}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self);level=try c.decode(Double.self,forKey:.level);pan=try c.decode(Double.self,forKey:.pan);controls=try c.decodeIfPresent([Double].self,forKey:.controls)
        enabled=try c.decodeIfPresent(Bool.self,forKey:.enabled) ?? true;channelEnabled=try c.decodeIfPresent(Bool.self,forKey:.channelEnabled) ?? true;selectedPattern=try c.decodeIfPresent(Int.self,forKey:.selectedPattern) ?? 0
        if let banks=try c.decodeIfPresent([DrumPattern].self,forKey:.patterns){patterns=banks;voices=try c.decode([DrumVoice].self,forKey:.voices)}else{
            // Assign through the compatibility view only after validating the selected bank.
            selectedPattern=0;let old=try c.decode([DrumLane].self,forKey:.lanes)
            guard old.count==11 else{throw DecodingError.dataCorruptedError(forKey:.lanes,in:c,debugDescription:"11 drum lanes required")}
            lanes=old;accentSteps=try c.decodeIfPresent([Bool].self,forKey:.accentSteps)
        }
    }
    public func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:CodingKeys.self);try c.encode(level,forKey:.level);try c.encode(pan,forKey:.pan);try c.encode(enabled,forKey:.enabled);try c.encode(channelEnabled,forKey:.channelEnabled);try c.encodeIfPresent(controls,forKey:.controls);try c.encode(selectedPattern,forKey:.selectedPattern);try c.encode(voices,forKey:.voices);try c.encode(patterns,forKey:.patterns)
    }
    public func valid(_ device:Int)->Bool {
        (0...31).contains(selectedPattern)&&patterns.count==32&&patterns.allSatisfy(\.valid)&&voices.count==11&&voices.allSatisfy{(-1...45).contains($0.sample)&&(0...1).contains($0.level)}&&(0...1).contains(level)&&(-1...1).contains(pan)&&(controls==nil || (controls!.count==DrumDefinitions.defaults(device).count&&controls!.allSatisfy{$0.isFinite&&(0...127).contains($0)}))
    }
}
public struct SongEvent:Codable,Equatable {
    public var tick:Int,device:Int,parameter:Int,value:Int
    public init(tick:Int,device:Int,parameter:Int,value:Int){self.tick=tick;self.device=device;self.parameter=parameter;self.value=value}
}
public struct Song:Codable,Equatable {
    public var version=3
    public var tempo=120.0,swing=0.0,master=100.0/127
    public var effects=[0.0,0.0,0.3,0.0,0.0]
    public var rack:EffectSettings?=EffectSettings()
    public var bass=[BassTrack(),BassTrack()]
    public var drums=[DrumTrack(device:0),DrumTrack(device:1)]
    public var songMode:Bool?=false,looping:Bool?=false
    public var loopStart:Int?=0,loopEnd:Int?=768
    public var events:[SongEvent]?
    public var midiNotes:[RecordedNote]?
    public var originalModName:String?
    public var highQuality:Bool?=true
    public var archiveData:Data?
    public var embeddedMod:Data?
    public var effectiveRack:EffectSettings {rack ?? EffectSettings.legacy(effects)}
    public init(){}
    public static func demo()->Song {
        var song=Song();let notes=[48,48,55,48,60,48,58,55,48,51,48,60,55,48,46,48]
        for d in 0..<2 {song.bass[d].pan=d==0 ? -0.2 : 0.2;for s in 0..<16{song.bass[d].steps[s]=BassStep(note:notes[s]+(d==0 ? 0:12),enabled:d==0 || s%3==0,accent:s%4==0,slide:s==6 || s==11)}}
        return song
    }
    public var valid:Bool {
        guard (embeddedMod?.count ?? 0)<=32*1024*1024,(1...3).contains(version),[tempo,swing,master].allSatisfy(\.isFinite),(30...300).contains(tempo),(0...0.45).contains(swing),(0...1).contains(master),effects.count==5,effects.allSatisfy({$0.isFinite&&(0...1).contains($0)}),rack==nil || rack!.valid,bass.count==2,drums.count==2,bass.allSatisfy(\.valid),drums.enumerated().allSatisfy({$0.element.valid($0.offset)}),(0...100_000_000).contains(loopStart ?? 0),((loopStart ?? 0)+1...100_000_001).contains(loopEnd ?? 768) else{return false}
        let timeline=events ?? [];guard timeline.count<=32768,(midiNotes?.count ?? 0)<=16384,(midiNotes ?? []).allSatisfy(\.valid) else{return false}
        return timeline.allSatisfy{(0...100_000_000).contains($0.tick)&&(0...8).contains($0.device)&&(0...127).contains($0.parameter)&&(0...127).contains($0.value)}&&zip(timeline,timeline.dropFirst()).allSatisfy{pair in pair.0.tick <= pair.1.tick}
    }
}
