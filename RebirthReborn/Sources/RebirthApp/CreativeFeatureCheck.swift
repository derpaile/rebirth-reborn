import SwiftUI
import AppKit
import RebirthDSP
import RebirthModel

// Exercises persistence, editing, MIDI routing and audio with isolated test files.
enum CreativeFeatureCheck {
    struct Failure:Error,CustomStringConvertible{let description:String;init(_ value:String){description=value}}
    @MainActor static func run(_ studio:Studio) async {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("rebirth-features-\(UUID().uuidString)",isDirectory:true)
        let previous=studio.song,mappings=studio.learnMappings,enabled=studio.midiEnabled,clock=studio.midiClockEnabled,library=studio.presets
        defer{studio.recording=false;studio.suppressHistory=true;studio.song=previous;studio.suppressHistory=false;studio.learnMappings=mappings;studio.midiClockEnabled=clock;studio.midiEnabled=enabled;studio.presets=library;try? FileManager.default.removeItem(at:root)}
        do {
            func require(_ value:Bool,_ label:String)throws{if !value{throw Failure(label)}}
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            studio.presets=PresetLibrary(directory:root)
            studio.song=Song.demo();studio.song.bass[0].controls[1]=19
            studio.savePreset(name:"Test sound",kind:.bassSound,device:0)
            guard let preset=studio.presets.entries.last else{throw Failure("Saved preset missing")}
            studio.song.bass[0].controls[1]=85;studio.applyPreset(preset,device:0)
            try require(studio.song.bass[0].controls[1]==19,"Preset application")
            studio.undo();try require(studio.song.bass[0].controls[1]==85,"Undo preset")
            studio.redo();try require(studio.song.bass[0].controls[1]==19,"Redo preset")
            try studio.presets.rename(preset.id,"Renamed")
            try require(PresetLibrary(directory:root).entries.contains{$0.name=="Renamed"},"Preset persistence/rename")
            for kind in PresetKind.allCases{studio.savePreset(name:kind.title,kind:kind,device:[.drumKit,.drumPattern].contains(kind) ? 2:0)}
            try require(studio.presets.entries.suffix(6).allSatisfy(\.valid),"All six preset kinds")
            studio.song=Song.demo();studio.setPattern(bar:2,device:0,pattern:17);studio.insertBar(1)
            try require(studio.patternAt(bar:3,device:0)==17,"Insert bar shifts arrangement")
            studio.duplicateBar(3);try require(studio.patternAt(bar:4,device:0)==17,"Duplicate bar pattern continuation")
            studio.removeBar(1);try require(studio.song.valid && studio.patternAt(bar:2,device:0)==17,"Remove bar preserves arrangement")
            var tracker=MIDIClockTracker(),bpm:Double?
            for pulse in 0..<30{bpm=tracker.pulse(at:Double(pulse)/48)}
            try require(abs((bpm ?? 0)-120)<1e-6,"24 PPQN clock estimate")
            var decoder=MIDIDecoder()
            try require(decoder.feed([0xf2,2,0xf8,1])==[MIDIMessage(status:0xf8),MIDIMessage(status:0xf2,first:2,second:1)],"Song-position parser with interleaved clock")
            studio.beginLearn(ControllerTarget(1,3))
            studio.handleMIDIInput([MIDIInputEvent(message:MIDIMessage(status:0xb0,first:74,second:100),source:42,seconds:0)])
            try require(studio.song.bass[0].controls[1]==100 && studio.learnMappings.contains{$0.source==42 && $0.cc==74},"MIDI learn and target application")
            studio.handleMIDIInput([MIDIInputEvent(message:MIDIMessage(status:0xb0,first:74,second:15),source:42,seconds:1)])
            try require(studio.song.bass[0].controls[1]==15,"Learned CC overrides default mapping")
            studio.midiClockEnabled=false;studio.song=Song.demo();studio.toggleRecording()
            try await Task.sleep(nanoseconds:30_000_000)
            studio.handleMIDIInput([MIDIInputEvent(message:MIDIMessage(status:0x90,first:60,second:112),source:42,seconds:2)])
            try await Task.sleep(nanoseconds:60_000_000)
            studio.handleMIDIInput([MIDIInputEvent(message:MIDIMessage(status:0x80,first:60,second:0),source:42,seconds:2.1)])
            studio.handleMIDIInput([MIDIInputEvent(message:MIDIMessage(status:0x99,first:36,second:110),source:42,seconds:2.1)])
            studio.toggleRecording()
            try require(studio.song.midiNotes?.contains{$0.device==0 && $0.note==60 && $0.velocity==112 && $0.duration>1}==true,"MIDI bass note recording")
            try require(studio.song.midiNotes?.contains{$0.device==2 && $0.note==0}==true,"MIDI drum recording")
            let decoded=try JSONDecoder().decode(Song.self,from:JSONEncoder().encode(studio.song))
            try require(decoded.midiNotes==studio.song.midiNotes && decoded.valid,"Recorded-note JSON persistence")
            var rejected=false;do{_ = try RebirthSongFile.write(decoded)}catch{rejected=true};try require(rejected,"RBS prevents recorded-note loss")
            let pack=try RebornSoundPack.make(name:"Feature pack",files:[RebornSoundPack.sampleNames[0]:try Studio.defaultSamples()[0]])
            let restoredPack=try RebornSoundPack.read(pack.archiveData)
            try require(restoredPack.name==pack.name && restoredPack.files==pack.files,"Native soundpack round-trip")
            studio.selectMod(restoredPack);try require(studio.song.originalModName==pack.name,"Native soundpack loading")
            studio.selectMod(nil);studio.song=Song.demo();studio.song.songMode=true;studio.song.looping=false
            let wav=root.appendingPathComponent("native.wav")
            let samples=try Studio.defaultSamples();try RebirthAudioFile.write(studio.song,samples:samples,to:wav)
            let comparison=try AudioComparison.compare(original:wav,native:wav)
            try require(comparison.offsetFrames==0 && comparison.maxError==0 && comparison.rmsError==0 && abs(comparison.correlation-1)<1e-10,"Audio comparison identity/alignment")
            let engine=rb_create()!;defer{rb_destroy(engine)}
            var song=Song();song.songMode=true;for d in 0..<2{song.bass[d].enabled=false; song.drums[d].enabled=false};song.midiNotes=[RecordedNote(tick:0,device:0,note:48,velocity:112,duration:96)]
            try require(song.apply(to:engine),"Recorded-note DSP queue")
            _ = rb_parameter(engine,4,0,1)
            var l=[Float](repeating:0,count:4096),r=l;rb_render(engine,&l,&r,4096)
            try require(l.contains{abs($0)>1e-5} && rb_faults(engine)==0,"Recorded-note audio playback")
            _ = rb_parameter(engine,4,0,0);rb_render(engine,&l,&r,64)
            _ = rb_midi_sync(engine,1);_ = rb_parameter(engine,4,0,1);rb_render(engine,&l,&r,4096)
            try require(rb_tick(engine)==0,"External clock waits for pulses")
            for _ in 0..<6{_ = rb_midi_clock(engine);rb_render(engine,&l,&r,64)}
            try require(rb_tick(engine)==48,"Six MIDI pulses advance one step")
            _ = rb_midi_sync(engine,0);rb_render(engine,&l,&r,4096);try require(rb_tick(engine)>48,"Internal clock resumes")
            let restored=rb_create()!,reference=rb_create()!;defer{rb_destroy(restored);rb_destroy(reference)}
            song.midiNotes=[RecordedNote(tick:0,device:0,note:48,velocity:112,duration:384),RecordedNote(tick:48,device:0,note:60,velocity:112,duration:48)]
            try require(song.apply(to:restored),"Overlapping-note queue");_ = rb_seek(restored,144);_ = rb_parameter(restored,4,0,1)
            song.midiNotes=[song.midiNotes![0]];try require(song.apply(to:reference),"Reference held-note queue");_ = rb_seek(reference,144);_ = rb_parameter(reference,4,0,1)
            var expected=l,expectedRight=r;rb_render(restored,&l,&r,4096);rb_render(reference,&expected,&expectedRight,4096)
            try require(zip(l,expected).allSatisfy{abs($0-$1)<1e-6},"Seek restores previous held bass note after overlapping release")
            _ = rb_parameter(restored,4,0,0);rb_render(restored,&l,&r,64);try RebirthSampleBank(samples).commit(to:restored)
            song.midiNotes=[RecordedNote(tick:0,device:2,note:0,velocity:127,duration:48)];try require(song.apply(to:restored),"Past-drum queue");_ = rb_seek(restored,144);_ = rb_parameter(restored,4,0,1);rb_render(restored,&l,&r,4096)
            try require(!l.contains{abs($0)>1e-5},"Seek does not retrigger past drum notes")
            print("FEATURE_CHECK_PASS: six preset kinds/persistence, undo/redo, arrangement insert/duplicate/remove, MIDI learn, 24 PPQN/SPP, bass/drum note recording, JSON/audio playback, RBS-loss guard, native soundpack, full-file comparison")
            studio.learnMappings=mappings;studio.midiClockEnabled=clock;studio.midiEnabled=enabled
            NSApplication.shared.terminate(nil)
        }catch{print("FEATURE_CHECK_FAIL: \(error)");studio.learnMappings=mappings;studio.midiClockEnabled=clock;studio.midiEnabled=enabled;exit(1)}
    }
}
