import Foundation
import AVFoundation
import RebornDSP
import RebornModel

func require(_ condition:Bool,_ message:String){if !condition{fputs("FAIL: \(message)\n",stderr);exit(1)}}
let samples=RemakeSoundBank.samples
require(samples.count==46 && samples.allSatisfy{$0.count>100},"46 synthesized AIFF voices")
func render(_ song:Song,frames:Int=44100)->[Float]{
    let engine=rb_create()!;defer{rb_destroy(engine)}
    do{try RebornSampleBank(samples).commit(to:engine)}catch{require(false,"Generated samples decode")}
    require(song.apply(to:engine),"Song command queue")
    _ = rb_parameter(engine,4,0,1)
    var left=[Float](repeating:0,count:frames),right=left
    rb_render(engine,&left,&right,UInt32(frames))
    require(rb_faults(engine)==0 && left.allSatisfy{$0.isFinite && abs($0)<=1},"Finite, bounded audio without hidden resets")
    return left
}
func difference(_ a:[Float],_ b:[Float])->Double{zip(a,b).reduce(0){$0+Double(abs($1.0-$1.1))}/Double(a.count)}
var song=Song.demo();for d in 0..<2{song.drums[d].enabled=false};song.bass[1].enabled=false
let plain=render(song)
require(plain.contains{abs($0)>1e-5},"Bass synthesis produces audio")
require(plain==render(song),"Deterministic render")
var modified=song;modified.bass[0].controls[1]=110;require(difference(plain,render(modified))>1e-6,"Cutoff changes audio")
modified=song;modified.bass[0].controls[6]=1;require(difference(plain,render(modified))>1e-6,"Square waveform changes audio")
modified=song;modified.highQuality=false;require(difference(plain,render(modified))>1e-8,"Oversampling is active")
for machine in 0..<2{for lane in 0..<11{
    var beat=Song();for d in 0..<2{beat.bass[d].enabled=false;beat.drums[d].enabled=d==machine}
    beat.drums[machine].patterns[0].hits[lane].steps[0]=true
    require(render(beat,frames:8192).contains{abs($0)>1e-5},"Drum \(machine)/\(lane) produces audio")
}}
let engine=rb_create()!;defer{rb_destroy(engine)}
require(rb_parameter(engine,0,3,.nan)==0 && rb_note_step(engine,0,16,48,1,0,0)==0,"Invalid commands rejected")
var left=[Float](repeating:1,count:4096),right=left;rb_render(engine,&left,&right,4096);require(left.allSatisfy{$0==0},"Stopped engine is silent")
var decoder=MIDIDecoder()
require(decoder.feed([0x90,60,100,61,0,0xf2,2,0xf8,1])==[MIDIMessage(status:0x90,first:60,second:100),MIDIMessage(status:0x90,first:61,second:0),MIDIMessage(status:0xf8),MIDIMessage(status:0xf2,first:2,second:1)],"MIDI running status and interleaved clock/SPP")
var tracker=MIDIClockTracker(),tempo:Double?
for pulse in 0..<30{tempo=tracker.pulse(at:Double(pulse)/48)}
require(abs((tempo ?? 0)-120)<1e-6,"24 PPQN clock")
var history=SongHistory();modified=song;modified.tempo=132;history.record(song,after:modified)
require(history.undo(modified)==song && history.redo(song)==modified,"Undo/redo")
require(RebornPreset.builtIn.allSatisfy(\.valid),"Factory presets valid")
let data=try JSONEncoder().encode(song);require(try JSONDecoder().decode(Song.self,from:data)==song,"Native JSON round-trip")
let rbs=try RebornSongFile.write(song);let loaded=try RebornSongFile.read(rbs);require(loaded.valid && loaded.bass[0].patterns==song.bass[0].patterns,"Self-created RBS round-trip")
modified=song;modified.songMode=true;modified.midiNotes=[RecordedNote(tick:0,device:0,note:60,velocity:112,duration:96)]
require(render(modified).contains{abs($0)>1e-5},"Recorded MIDI playback")
var refused=false;do{_ = try RebornSongFile.write(modified)}catch{refused=true};require(refused,"RBS rejects native MIDI-note loss")
let pack=try RebornSoundPack.make(name:"Test pack",files:[RebornSoundPack.sampleNames[0]:samples[0]])
require(try RebornSoundPack.read(pack.archiveData).files==pack.files,"Open soundpack round-trip")
let wav=FileManager.default.temporaryDirectory.appendingPathComponent("reborn-test-\(UUID().uuidString).wav")
defer{try? FileManager.default.removeItem(at:wav)}
modified.looping=false;modified.loopEnd=768;try RebornAudioFile.write(modified,samples:samples,to:wav)
let comparison=try AudioComparison.compare(original:wav,native:wav)
require(comparison.rmsError==0 && comparison.offsetFrames==0,"WAV export and full-file comparison")
print("PASS: asset-free synthesis, 22 drum voices, deterministic audio, controls/oversampling, bounds, MIDI/clock, presets, history, JSON/RBS/soundpack round-trips and WAV export/comparison.")
