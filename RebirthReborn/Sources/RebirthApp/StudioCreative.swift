import SwiftUI
import AppKit
import UniformTypeIdentifiers
import RebirthDSP
import RebirthModel

extension Studio {
    var canUndo:Bool{history.canUndo && !recording}
    var canRedo:Bool{history.canRedo && !recording}
    func songDidChange(_ before:Song){
        guard !suppressHistory,!recording,before != song else{return}
        let changes=song.controllerChanges(from:before,at:0)
        let single=changes.count==1 && before.bass.map(\.patterns)==song.bass.map(\.patterns) && before.drums.map(\.patterns)==song.drums.map(\.patterns) && before.events==song.events && before.midiNotes==song.midiNotes
        let key=single ? "\(changes[0].device):\(changes[0].parameter)":""
        history.record(before,after:song,label:single ? ControllerTarget(changes[0].device,changes[0].parameter).label:"Song bearbeiten",key:key)
    }
    func undo(){guard canUndo,let previous=history.undo(song) else{return};if playing{togglePlayback()};suppressHistory=true;song=previous;suppressHistory=false;sync()}
    func redo(){guard canRedo,let next=history.redo(song) else{return};if playing{togglePlayback()};suppressHistory=true;song=next;suppressHistory=false;sync()}
    func editSong(_ label:String,_ update:(inout Song)->Void){
        guard !recording else{return}
        var next=song;update(&next);guard next.valid else{error="Ungültige Song-Änderung.";return}
        if playing{togglePlayback()}
        let before=song;suppressHistory=true;song=next;suppressHistory=false;history.record(before,after:next,label:label);sync()
    }
    func savePreset(name:String,kind:PresetKind,device:Int){
        var preset=RebirthPreset(name:name,kind:kind)
        switch kind {
        case .bassSound:preset.bass=song.bass[min(1,max(0,device))]
        case .drumKit:let d=min(1,max(0,device-2));preset.drum=song.drums[d];preset.drumDevice=d;preset.modName=song.originalModName;preset.modData=song.embeddedMod
        case .effects:preset.effect=song.effectiveRack
        case .bassPattern:let d=min(1,max(0,device));preset.bassPattern=song.bass[d].patterns[song.bass[d].selectedPattern]
        case .drumPattern:let d=min(1,max(0,device-2));preset.drumPattern=song.drums[d].patterns[song.drums[d].selectedPattern]
        case .rack:preset.song=song
        }
        do{try presets.add(preset)}catch{self.error=error.localizedDescription}
    }
    func applyPreset(_ preset:RebirthPreset,device:Int){
        guard preset.valid,!recording else{return}
        if preset.kind == .drumKit,preset.drumDevice != device-2{error="Dieses Drumkit gehört zur \(preset.drumDevice==0 ? "808":"909").";return}
        editSong("Preset: "+preset.name){next in
            switch preset.kind {
            case .bassSound:let d=min(1,max(0,device));next.bass[d].controls=preset.bass!.controls;next.bass[d].level=preset.bass!.level;next.bass[d].pan=preset.bass!.pan
            case .drumKit:let d=min(1,max(0,device-2));next.drums[d].voices=preset.drum!.voices;next.drums[d].controls=preset.drum!.controls;next.drums[d].level=preset.drum!.level;next.drums[d].pan=preset.drum!.pan;next.originalModName=preset.modName ?? "Reborn Standard";next.embeddedMod=preset.modData
            case .effects:next.rack=preset.effect
            case .bassPattern:let d=min(1,max(0,device));next.bass[d].patterns[next.bass[d].selectedPattern]=preset.bassPattern!
            case .drumPattern:let d=min(1,max(0,device-2));next.drums[d].patterns[next.drums[d].selectedPattern]=preset.drumPattern!
            case .rack:next=preset.song!
            }
        }
    }
    func exportPreset(_ preset:RebirthPreset){let panel=NSSavePanel();panel.allowedContentTypes=[.json];panel.nameFieldStringValue=preset.name+".json";guard panel.runModal() == .OK,let url=panel.url else{return};do{try JSONEncoder().encode(preset).write(to:url,options:.atomic)}catch{self.error=error.localizedDescription}}
    func importPreset(){let panel=NSOpenPanel();panel.allowedContentTypes=[.json];guard panel.runModal() == .OK,let url=panel.url else{return};do{let data=try Data(contentsOf:url);guard data.count<=64*1024*1024 else{throw PresetLibrary.LibraryError.invalid};var preset=try JSONDecoder().decode(RebirthPreset.self,from:data);preset.id=UUID();try presets.add(preset)}catch{self.error=error.localizedDescription}}
    func patternAt(bar:Int,device:Int)->Int {
        var result=device<2 ? song.bass[device].selectedPattern:song.drums[device-2].selectedPattern
        for event in song.events ?? [] where event.tick<=bar*768 && event.device==device+1 && event.parameter==1{result=event.value}
        return result
    }
    func setPattern(bar:Int,device:Int,pattern:Int){editSong("Pattern im Song"){next in var events=next.events ?? [];events.removeAll{$0.tick==bar*768 && $0.device==device+1 && $0.parameter==1};events.append(SongEvent(tick:bar*768,device:device+1,parameter:1,value:pattern));next.events=events.sorted{$0.tick<$1.tick};next.songMode=true;next.loopEnd=max(next.loopEnd ?? 768,(bar+1)*768)}}
    func insertBar(_ bar:Int){editSong("Takt einfügen"){next in next.events=(next.events ?? []).map{var event=$0;if event.tick>=bar*768{event.tick+=768};return event};next.midiNotes=(next.midiNotes ?? []).map{var note=$0;if note.tick>=bar*768{note.tick+=768};return note};if (next.loopStart ?? 0)>=bar*768{next.loopStart=(next.loopStart ?? 0)+768};next.loopEnd=(next.loopEnd ?? 768)+768}}
    func removeBar(_ bar:Int){editSong("Takt entfernen"){next in let from=bar*768,to=from+768;next.events=(next.events ?? []).filter{!($0.tick>=from && $0.tick<to)}.map{var event=$0;if event.tick>=to{event.tick-=768};return event};next.midiNotes=(next.midiNotes ?? []).filter{!($0.tick>=from && $0.tick<to)}.map{var note=$0;if note.tick>=to{note.tick-=768};return note};next.loopStart=max(0,(next.loopStart ?? 0)-((next.loopStart ?? 0)>=to ? 768:0));next.loopEnd=max((next.loopStart ?? 0)+768,(next.loopEnd ?? 768)-768)}}
    func duplicateBar(_ bar:Int){let events=(song.events ?? []).filter{$0.tick>=bar*768 && $0.tick<(bar+1)*768};let notes=(song.midiNotes ?? []).filter{$0.tick>=bar*768 && $0.tick<(bar+1)*768};var next=song;let at=(bar+1)*768;next.events=(next.events ?? []).map{var e=$0;if e.tick>=at{e.tick+=768};return e};next.events! += events.map{var e=$0;e.tick+=768;return e};for d in 0..<4{if !events.contains(where:{$0.device==d+1 && $0.parameter==1}){next.events!.append(SongEvent(tick:at,device:d+1,parameter:1,value:patternAt(bar:bar,device:d)))}};next.events!.sort{$0.tick<$1.tick};next.midiNotes=(next.midiNotes ?? []).map{var n=$0;if n.tick>=at{n.tick+=768};return n}+notes.map{var n=$0;n.id=UUID();n.tick+=768;return n};next.loopEnd=(next.loopEnd ?? 768)+768;editSong("Takt duplizieren"){$0=next}}
    func applyController(_ target:ControllerTarget,value:Int){
        guard target.valid else{return};let v=min(target.range.upperBound,max(target.range.lowerBound,value)),d=target.device,p=target.parameter
        if d==3 || d==4,p>=2{drumControl(device:d-3,parameter:p).wrappedValue=Double(v);return}
        changeController(d,p,v){
            if d==0{var rack=song.effectiveRack;if p==1{rack.compressorTarget=v}else if p==2{rack.pcfTarget=v}else{let channel=(p-6)/6;switch (p-6)%6{case 0:if channel<2{song.bass[channel].level=Double(v)/127}else{song.drums[channel-2].level=Double(v)/127};case 1:if channel<2{song.bass[channel].pan=Double(v)/63.5-1}else{song.drums[channel-2].pan=Double(v)/63.5-1};case 2:rack.sends[channel]=Double(v);default:rack.distorted[channel]=v != 0}};song.rack=rack
            }else if d<=4{let device=d-1;if device<2{if p==0{song.bass[device].enabled=v != 0}else if p==1{song.bass[device].selectedPattern=v}else{song.bass[device].controls[p-2]=Double(v)}}else{if p==0{song.drums[device-2].enabled=v != 0}else{song.drums[device-2].selectedPattern=v}}}
            else{var rack=song.effectiveRack;switch d{case 5:rack.delay[p]=Double(v);case 6:rack.distortion[p]=Double(v);case 7:rack.pcf[p]=Double(v);default:rack.compressor[p]=Double(v)};song.rack=rack}
        }
    }
    func beginLearn(_ target:ControllerTarget){guard target.valid else{return};midiEnabled=true;learnTarget=target}
    func configureClock(){_ = rb_midi_sync(dsp,midiEnabled && midiClockEnabled ? 1:0);clockTracker.reset();activeClockSource=nil;clockTempo=nil;UserDefaults.standard.set(midiClockEnabled,forKey:"midiClock")}
    func captureNote(device:Int,note:Int,velocity:Int,on:Bool){
        guard recording else{return};if on,(recordBase?.midiNotes?.count ?? 0)+recordedNotes.count+pendingRecordedNotes.count>=16384{finishRecording();error="Die Aufnahme hat die Grenze von 16384 Noten erreicht.";return};let tick=Int(rb_tick(dsp)),key="\(device):\(note)"
        if let pending=pendingRecordedNotes.removeValue(forKey:key),recordedNotes.count<16384{recordedNotes.append(RecordedNote(tick:pending.tick,device:device,note:note,velocity:pending.velocity,duration:max(1,tick-pending.tick)))}
        if on,recordedNotes.count<16384{if device>=2{recordedNotes.append(RecordedNote(tick:tick,device:device,note:note,velocity:velocity,duration:48))}else{pendingRecordedNotes[key]=(tick,velocity)}}
    }
    func handleMIDIInput(_ input:[MIDIInputEvent]){
        guard midiEnabled else{return}
        for event in input {
            let message=event.message,status=message.status,channel=status&15,type=status&0xf0
            if midiClockEnabled,[0xf8,0xfa,0xfb,0xfc,0xf2].contains(status){
                if clockSource==0 && activeClockSource==nil && [0xf8,0xfa].contains(status){activeClockSource=event.source}
                if let selected=clockSource==0 ? activeClockSource:clockSource,selected != event.source{continue}
            }
            if status==0xf8{
                guard midiClockEnabled,(clockSource==0 || clockSource==event.source) else{continue}
                if let tempo=clockTracker.pulse(at:event.seconds){if clockTempo==nil || abs((clockTempo ?? 0)-tempo)>0.1{clockTempo=tempo};if abs(song.tempo-tempo)>0.2{suppressHistory=true;song.tempo=tempo;suppressHistory=false;sync()}}
                _ = rb_midi_clock(dsp);continue
            }
            if midiClockEnabled,clockSource != 0,clockSource != event.source,[0xfa,0xfb,0xfc,0xf2].contains(status){continue}
            if status==0xfa{clockTracker.reset();if playing{togglePlayback()};seek(0);togglePlayback();continue}
            if status==0xfb{if !playing{togglePlayback()};continue}
            if status==0xfc{if playing{togglePlayback()};continue}
            if status==0xf2{seek((message.first+message.second*128)*48);continue}
            if type==0xb0 {
                if channel<2 && [120,123].contains(message.first){
                    let pitches=pendingRecordedNotes.keys.filter{$0.hasPrefix("\(channel):")}.compactMap{Int($0.split(separator:":").last ?? "")}
                    for pitch in pitches{captureNote(device:channel,note:pitch,velocity:0,on:false)}
                    handleMIDI([message]);continue
                }
                if let target=learnTarget {learnMappings.removeAll{$0.source==event.source && $0.channel==channel && $0.cc==message.first};learnMappings.append(MIDILearnedControl(source:event.source,channel:channel,cc:message.first,target:target));learnTarget=nil}
                if let mapping=learnMappings.first(where:{$0.source==event.source && $0.channel==channel && $0.cc==message.first}){let range=mapping.target.range;applyController(mapping.target,value:range.lowerBound+Int((Double(message.second)*Double(range.upperBound-range.lowerBound)/127).rounded()));continue}
            }
            if channel<2 && (type==0x90 || type==0x80),message.first<=95{
                let on=type==0x90 && message.second>0;captureNote(device:channel,note:message.first,velocity:message.second,on:on)
            }else if [9,10].contains(channel),type==0x90,message.second>0{
                let machine=channel-9,map=machine==0 ? [36:0,38:1,40:1,45:2,47:3,50:4,37:5,39:6,56:7,49:8,46:9,42:10]:[36:0,38:1,40:1,45:2,47:3,50:4,37:5,39:6,42:7,46:8,49:9,51:10]
                if let lane=map[message.first]{captureNote(device:machine+2,note:lane,velocity:message.second,on:true)}
            }
            handleMIDI([message])
        }
    }
}
