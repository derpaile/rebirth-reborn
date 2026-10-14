import Foundation

public enum RebornSongFile {
    public enum ReadError:LocalizedError {
        case malformed(String)
        public var errorDescription:String? {if case .malformed(let text)=self{return "ReBirth-Datei: "+text};return nil}
    }
    private struct Chunk {var tag:String,type:String?,bytes:[UInt8],children:[Chunk]}
    private static func be(_ bytes:[UInt8],_ at:Int)->Int {Int(bytes[at])<<24|Int(bytes[at+1])<<16|Int(bytes[at+2])<<8|Int(bytes[at+3])}
    private static func text(_ bytes:[UInt8])->String {String(bytes:bytes.prefix{$0 != 0},encoding:.isoLatin1) ?? ""}
    private static func walk(_ data:[UInt8],_ start:Int,_ end:Int,_ depth:Int=0)throws->[Chunk] {
        guard depth<=8 else{throw ReadError.malformed("Zu viele verschachtelte Blöcke.")}
        var at=start,result=[Chunk]()
        while at<end {
            guard at<=end-8,let tag=String(bytes:data[at..<at+4],encoding:.ascii) else{throw ReadError.malformed("Unvollständiger Blockkopf.")}
            let size=be(data,at+4),payload=at+8
            guard size<=end-payload else{throw ReadError.malformed("Block überschreitet die Dateigrenze.")}
            let stop=payload+size
            var chunk=Chunk(tag:tag,type:nil,bytes:Array(data[payload..<stop]),children:[])
            if ["CAT ","FORM","LIST"].contains(tag) {
                guard size>=4,let type=String(bytes:data[payload..<payload+4],encoding:.ascii) else{throw ReadError.malformed("Container ohne Typ.")}
                chunk.type=type;chunk.children=try walk(data,payload+4,stop,depth+1)
            }
            result.append(chunk);at=stop+(size&1)
        }
        guard at==end else{throw ReadError.malformed("Fehlerhafte Blockausrichtung.")};return result
    }
    public static func read(_ url:URL)throws->Song {try read(Data(contentsOf:url))}
    public static func read(_ data:Data)throws->Song {
        guard data.count<=16*1024*1024 else{throw ReadError.malformed("Song ist zu groß.")}
        let roots=try walk(Array(data),0,data.count)
        guard roots.count==1,roots[0].tag=="CAT ",roots[0].type=="RB40" else{throw ReadError.malformed("RB40-Songcontainer fehlt.")}
        let root=roots[0]
        func unique(_ chunks:[Chunk],_ tag:String,_ size:Int)throws->[UInt8] {
            let match=chunks.filter{$0.tag==tag};guard match.count==1,match[0].bytes.count==size else{throw ReadError.malformed("Ungültiger "+tag+"-Block.")};return match[0].bytes
        }
        let head=try unique(root.children,"HEAD",256)
        guard be(head,0)==0x5b545b54 else{throw ReadError.malformed("Unbekannte Songkennung.")}
        let oldMixer=head[6]==0 && head[7]==0
        let global=try unique(root.children,"GLOB",512)
        guard let dev=root.children.first(where:{$0.tag=="CAT "&&$0.type=="DEVL"}) else{throw ReadError.malformed("Geräte fehlen.")}
        var song=Song();song.archiveData=data;song.originalModName=text(Array(global[15..<80]));song.tempo=Double(be(global,2))/1000;song.swing=Double(global[14])/288;song.songMode=global[0] != 0;song.looping=global[1] != 0;song.loopStart=be(global,6);song.loopEnd=be(global,10)
        let mixer=try unique(dev.children,"MIXR",64)
        song.master=Double(mixer[0])/127
        var rack=EffectSettings();rack.compressorTarget=Int(mixer[1]);rack.pcfTarget=Int(mixer[2])
        rack.delay=Array((try unique(dev.children,"DELY",8)).prefix(5)).map(Double.init)
        rack.pcf=Array((try unique(dev.children,"PCF ",12)).prefix(7)).map(Double.init)
        rack.distortion=Array((try unique(dev.children,"DIST",8)).prefix(3)).map(Double.init)
        rack.compressor=Array((try unique(dev.children,"COMP",8)).prefix(3)).map(Double.init)
        for device in 0..<4 {
            let at=16+12*device
            let level=Double(mixer[at+1])/127,pan=Double(mixer[at+2])/63.5-1
            rack.sends[device]=Double(mixer[at+3]);rack.distorted[device]=mixer[at+4] != 0
            if device<2{song.bass[device].level=level;song.bass[device].pan=pan;song.bass[device].channelEnabled=mixer[at] != 0}else{song.drums[device-2].level=level;song.drums[device-2].pan=pan;song.drums[device-2].channelEnabled=mixer[at] != 0}
        }
        if oldMixer {
            // Native file-format compatibility.
            rack.compressorTarget=mixer[1]==0 ? 0:1;rack.pcfTarget=0
            for d in 0..<4 {
                if mixer[16+12*d+5] != 0{rack.pcfTarget=d+1}
                if mixer[16+12*d+6] != 0{rack.compressorTarget=d+2}
                if d<2{song.bass[d].channelEnabled=true}else{song.drums[d-2].channelEnabled=true}
            }
        }
        song.rack=rack
        let bass=dev.children.filter{$0.tag=="303 "}
        guard bass.count==2,bass.allSatisfy({$0.bytes.count==1097}) else{throw ReadError.malformed("Zwei 303-Bänke benötigt.")}
        for device in 0..<2 {
            let bytes=bass[device].bytes
            song.bass[device].enabled=bytes[0] != 0;song.bass[device].selectedPattern=Int(bytes[1]);song.bass[device].controls=Array(bytes[2..<9]).map(Double.init)
            for pattern in 0..<32 {
                let at=9+pattern*34
                var p=BassPattern();p.shuffled=bytes[at] != 0;p.length=Int(bytes[at+1])
                for step in 0..<16 {
                    let pitch=Int(bytes[at+2+step*2]),flags=bytes[at+3+step*2]
                    guard pitch<=12 else{throw ReadError.malformed("Unbekannte 303-Tonhöhe.")}
                    p.steps[step]=BassStep(note:48+pitch+((flags&4) != 0 ? 12:0)-((flags&8) != 0 ? 12:0),enabled:(flags&16)==0,accent:(flags&2) != 0,slide:(flags&1) != 0)
                }
                song.bass[device].patterns[pattern]=p
            }
        }
        for device in 0..<2 {
            let count=device==0 ? 29:30,header=count+1
            let bytes=try unique(dev.children,device==0 ? "808 ":"909 ",header+32*194)
            var config=Array(bytes.prefix(count)).map(Double.init)
            if device==1 {
                // Native file-format compatibility.
                config[20]=Double(bytes[22]);config[21]=Double(bytes[20]);config[22]=Double(bytes[21])
                // The original reader copies field 13 into field 16.
                config[16]=Double(bytes[13])
            }
            song.drums[device].enabled=bytes[0] != 0;song.drums[device].selectedPattern=Int(bytes[1]);song.drums[device].controls=config
            for lane in 0..<11 {song.drums[device].voices[lane].level=config[DrumDefinitions.levels[device][lane]]/127}
            for pattern in 0..<32 {
                let at=header+pattern*194
                var p=DrumPattern();p.shuffled=bytes[at] != 0;p.length=Int(bytes[at+1])
                for step in 0..<16 {
                    let row=at+2+step*12;p.accents[step]=bytes[row] != 0
                    for lane in 0..<11 {
                        let hit=bytes[row+lane+1]
                        guard hit<=4 else{throw ReadError.malformed("Unbekannter Drum-Anschlag.")}
                        p.hits[lane].steps[step]=hit != 0;p.hits[lane].strong[step]=(hit==2 || hit==4);p.hits[lane].flam[step]=hit>2
                    }
                }
                song.drums[device].patterns[pattern]=p
            }
        }
        guard let tracks=root.children.first(where:{$0.tag=="CAT "&&$0.type=="TRKL"}) else{throw ReadError.malformed("Song-Spuren fehlen.")}
        let trackChunks=tracks.children.filter{$0.tag=="TRAK"};guard trackChunks.count==9 else{throw ReadError.malformed("Neun Gerätespuren benötigt.")}
        var events=[SongEvent]()
        for (device,chunk) in trackChunks.enumerated() {
            let bytes=chunk.bytes;guard bytes.count>=4 else{throw ReadError.malformed("Leere Spur.")}
            let count=be(bytes,0);guard count<=32768,events.count+count<=32768 else{throw ReadError.malformed("Zu viele Song-Ereignisse.")}
            var at=4,time=0
            for _ in 0..<count {
                var delta=0,more=true,width=0
                while more {
                    guard at<bytes.count,width<5 else{throw ReadError.malformed("Ungültiger Zeitwert.")}
                    let byte=bytes[at];at+=1;width+=1;more=(byte&128) != 0;delta=(delta<<7)|Int(byte&127)
                }
                guard delta<=(100_000_000/24)-time,at<=bytes.count-2 else{throw ReadError.malformed("Ungültige Spurgrenze.")}
                time+=delta;let parameter=Int(bytes[at]),value=Int(bytes[at+1]);at+=2
                events.append(SongEvent(tick:time*24,device:device,parameter:parameter,value:value))
            }
            guard at==bytes.count else{throw ReadError.malformed("Spur enthält unerklärte Restdaten.")}
        }
        if oldMixer {
            // Native file-format compatibility.
            // routing enables win over disables; zero flags at time 0 are skipped.
            var converted=[SongEvent](),lastCompressor=0,lastPCF=0
            for e in events {
                guard e.device==0 else{converted.append(e);continue}
                var event=e
                if e.parameter==1 {
                    if e.value==0 && e.tick<=lastCompressor{continue}
                    event.value=e.value==0 ? 0:1;lastCompressor=e.tick
                }else if (4...34).contains(e.parameter) {
                    let channel=(e.parameter-4)/8,field=(e.parameter-4)%8
                    guard channel<4 else{continue}
                    switch field {
                    case 0...4:event.parameter=5+channel*6+field
                    case 5:
                        if e.value==0 && e.tick<=lastPCF{continue}
                        event.parameter=2;event.value=e.value==0 ? 0:channel+1;lastPCF=e.tick
                    case 6:
                        if e.value==0 && e.tick<=lastCompressor{continue}
                        event.parameter=1;event.value=e.value==0 ? 0:channel+2;lastCompressor=e.tick
                    default:continue
                    }
                }else if e.parameter != 0{continue}
                converted.append(event)
            }
            events=converted
        }
        // Preserve equal-time ordering within each device, as encoded in the file.
        song.events=events.enumerated().sorted{a,b in a.element.tick==b.element.tick ? a.offset<b.offset:a.element.tick<b.element.tick}.map(\.element)
        guard song.valid else{throw ReadError.malformed("Regler, Muster oder Songwerte liegen außerhalb des belegten Bereichs.")}
        return song
    }
}

extension RebornSongFile {
    public static func write(_ song:Song)throws->Data {
        guard song.valid else{throw ReadError.malformed("Ungültiger Song.")}
        guard (song.midiNotes ?? []).isEmpty else{throw ReadError.malformed("Aufgenommene MIDI-Noten benötigen das native JSON-Format.")}
        guard song.drums.allSatisfy({$0.voices.allSatisfy{$0.sample == -1}}) else{throw ReadError.malformed("Eigene Sample-Zuordnungen bitte als nativen JSON-Song sichern.")}
        func u32(_ n:Int)->[UInt8] {[(UInt8((n>>24)&255)),UInt8((n>>16)&255),UInt8((n>>8)&255),UInt8(n&255)]}
        func put(_ bytes:inout [UInt8],_ at:Int,_ n:Int){bytes.replaceSubrange(at..<at+4,with:u32(n))}
        func chunk(_ tag:String,_ bytes:[UInt8])->[UInt8] {Array(tag.utf8)+u32(bytes.count)+bytes+(bytes.count&1==1 ? [0]:[])}
        func integer(_ d:Double)->UInt8 {UInt8(min(127,max(0,d.rounded())))}
        let root:Chunk?
        if let data=song.archiveData,data.count<=16*1024*1024{root=(try? walk(Array(data),0,data.count))?.first}else{root=nil}
        func original(_ tag:String,_ count:Int)->[UInt8] {
            root?.children.first(where:{$0.tag==tag&&$0.bytes.count==count})?.bytes ?? Array(repeating:0,count:count)
        }
        var head=original("HEAD",256);head.replaceSubrange(0..<8,with:[0x5b,0x54,0x5b,0x54,0xbc,4,1,0])
        var global=original("GLOB",512)
        global[0]=(song.songMode ?? false) ? 1:0;global[1]=(song.looping ?? false) ? 1:0
        put(&global,2,Int((song.tempo*1000).rounded()));put(&global,6,song.loopStart ?? 0);put(&global,10,song.loopEnd ?? 768);global[14]=integer(song.swing*288)
        let modName=song.originalModName ?? "Reborn² Standard"
        guard let name=modName.data(using:.isoLatin1),name.count<65 else{throw ReadError.malformed("Mod-Name passt nicht in das RBS-Format.")}
        global.replaceSubrange(15..<80,with:Array(name)+Array(repeating:0,count:65-name.count))
        let rack=song.effectiveRack
        var mix=Array(repeating:UInt8(0),count:64);mix[0]=integer(song.master*127);mix[1]=UInt8(rack.compressorTarget);mix[2]=UInt8(rack.pcfTarget)
        for d in 0..<4 {
            let at=16+12*d,level=d<2 ? song.bass[d].level:song.drums[d-2].level,pan=d<2 ? song.bass[d].pan:song.drums[d-2].pan,on=d<2 ? song.bass[d].channelEnabled:song.drums[d-2].channelEnabled
            mix[at]=on ? 1:0;mix[at+1]=integer(level*127);mix[at+2]=integer((pan+1)*63.5);mix[at+3]=integer(rack.sends[d]);mix[at+4]=rack.distorted[d] ? 1:0
        }
        func effect(_ tag:String,_ controls:[Double],_ size:Int)->[UInt8] {chunk(tag,controls.map(integer)+Array(repeating:0,count:size-controls.count))}
        var devices=chunk("MIXR",mix)+effect("DELY",rack.delay,8)+effect("PCF ",rack.pcf,12)+effect("DIST",rack.distortion,8)+effect("COMP",rack.compressor,8)
        for track in song.bass {
            var b:[UInt8]=[track.enabled ? 1:0,UInt8(track.selectedPattern)]+track.controls.map(integer)
            b[8]=track.controls[6]>0.5 ? 1:0
            for pattern in track.patterns {
                b += [pattern.shuffled ? 1:0,UInt8(pattern.length)]
                for step in pattern.steps {
                    guard (36...72).contains(step.note) else{throw ReadError.malformed("RBS speichert 303-Noten nur von C2 bis C5. Für andere Noten bitte JSON nutzen.")}
                    var pitch=step.note-48,flags:UInt8=(step.slide ? 1:0)|(step.accent ? 2:0)|(step.enabled ? 0:16)
                    if pitch<0{pitch+=12;flags|=8}else if pitch>=12{pitch-=12;flags|=4}
                    b += [UInt8(pitch),flags]
                }
            }
            devices += chunk("303 ",b)
        }
        for d in 0..<2 {
            let track=song.drums[d];var b=(track.controls ?? DrumDefinitions.defaults(d)).map(integer)
            b[0]=track.enabled ? 1:0;b[1]=UInt8(track.selectedPattern)
            for lane in 0..<11 {b[DrumDefinitions.levels[d][lane]]=integer(track.voices[lane].level*127)}
            if d==1 {let rim=b[20],clap=b[21],hat=b[22];b[20]=clap;b[21]=hat;b[22]=rim}
            b.append(0)
            for pattern in track.patterns {
                b += [pattern.shuffled ? 1:0,UInt8(pattern.length)]
                for step in 0..<16 {
                    b.append(pattern.accents[step] ? (d==0 ? 1:2):0)
                    for hit in pattern.hits {b.append(hit.steps[step] ? UInt8((hit.strong[step] ? 2:1)+(hit.flam[step] ? 2:0)):0)}
                }
            }
            devices += chunk(d==0 ? "808 ":"909 ",b)
        }
        var tracks=[UInt8]()
        for d in 0..<9 {
            let events=(song.events ?? []).filter{$0.device==d};var b=u32(events.count),time=0
            for event in events {
                guard event.tick%24==0 else{throw ReadError.malformed("RBS-Ereignisse benötigen das originale Zeitraster.")}
                var delta=event.tick/24-time;time=event.tick/24;var vlq=[UInt8(delta&127)];delta>>=7
                while delta>0{vlq.insert(UInt8(delta&127)|128,at:0);delta>>=7}
                b += vlq+[UInt8(event.parameter),UInt8(event.value)]
            }
            tracks += chunk("TRAK",b)
        }
        let payload=Array("RB40".utf8)+chunk("HEAD",head)+chunk("GLOB",global)+chunk("USRI",original("USRI",712))+chunk("CAT ",Array("DEVL".utf8)+devices)+chunk("CAT ",Array("TRKL".utf8)+tracks)
        return Data(chunk("CAT ",payload))
    }
}
