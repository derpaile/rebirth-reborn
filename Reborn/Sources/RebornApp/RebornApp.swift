import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import RebornDSP
import RebornModel

final class Studio: ObservableObject {
    @Published var song = Song.demo(){didSet{songDidChange(oldValue)}}
    @Published var playing = false
    @Published var recording=false
    var liveControllers=Array(repeating:Array(repeating:-1,count:32),count:9)
    var currentTick=0
    @Published var midiEnabled=false{didSet{configureMIDI()}}
    var history=SongHistory(),suppressHistory=false
    var presets=PresetLibrary()
    @Published var presetDevice=0
    @Published var midiClockEnabled=UserDefaults.standard.bool(forKey:"midiClock"){didSet{configureClock()}}
    @Published var clockSource:Int32=0{didSet{configureClock()}}
    var activeClockSource:Int32?
    @Published var clockTempo:Double?
    var clockTracker=MIDIClockTracker()
    @Published var learnTarget:ControllerTarget?
    @Published var lastTouchedController:ControllerTarget?
    @Published var learnMappings:[MIDILearnedControl]=(UserDefaults.standard.data(forKey:"midiLearn").flatMap{try? JSONDecoder().decode([MIDILearnedControl].self,from:$0)} ?? []).filter(\.valid){didSet{if let data=try? JSONEncoder().encode(learnMappings){UserDefaults.standard.set(data,forKey:"midiLearn")}}}
    @Published var useModSkin=true
    @Published var modSkin:RackSkin?
    var recordedNotes=[RecordedNote](),pendingRecordedNotes=[String:(tick:Int,velocity:Int)]()
    var recordBase:Song?
    private var recordedEvents=[SongEvent]()
    private var midi:RebornMIDI?
    private var heldNotes:[[(note:Int,velocity:Int)]]=[[],[]]
    var currentStep = -1
    var deviceSteps=[-1,-1,-1,-1]
    var devicePatterns=[0,0,0,0]
    var peak: Float = 0
    @Published var error: String?
    @Published var availableMods:[RebornSoundPack]=[]
    @Published var activeMod:RebornSoundPack?{didSet{modSkin=activeMod.flatMap{RackSkin(mod:$0)}}}
    private var loadedModData:Data?
    private var loadedModName="Reborn² Standard"
    static func defaultSamples()throws->[Data]{RemakeSoundBank.samples}
    func resolveMod(_ song:Song)throws->RebornSoundPack? {
        guard let name=song.originalModName,!name.isEmpty,!["Reborn² Standard","Reborn Standard","Rebirth Standard","Standard ReBirth"].contains(name) else{return nil}
        if let data=song.embeddedMod {
            if activeMod?.archiveData==data,activeMod?.name==name{return activeMod}
            let mod=try RebornSoundPack.read(data)
            guard mod.name==name else{throw RebornSoundPack.ReadError.invalid("Song und Mod-Kennung stimmen nicht überein.")};return mod
        }
        guard let mod=availableMods.first(where:{$0.name==name}) else{throw RebornSoundPack.ReadError.invalid("„\(name)“ fehlt. Bitte das passende Reborn-Soundpack öffnen.")};return mod
    }
    private func ensureSamples(_ next:Song)throws {
        let name=next.originalModName.flatMap{$0.isEmpty ? nil:$0} ?? "Reborn² Standard"
        guard loadedModName != name || loadedModData != next.embeddedMod else{return}
        let mod=try resolveMod(next),defaults=try Self.defaultSamples()
        let bank=try RebornSampleBank(try mod?.samples(fallback:defaults) ?? defaults)
        let running=audio.isRunning;audio.stop()
        _ = rb_parameter(dsp,4,0,0)
        var left=[Float](repeating:0,count:128),right=left
        rb_render(dsp,&left,&right,128)
        try bank.commit(to:dsp)
        activeMod=mod;loadedModName=name;loadedModData=next.embeddedMod;playing=false;heldNotes=[[],[]];applied=nil
        if running{try audio.start()}
    }
    func selectMod(_ mod:RebornSoundPack?,demo:Bool=false) {
        if recording{finishRecording()}
        do {
            var next=demo && mod?.demo != nil ? try RebornSongFile.read(mod!.demo!):song
            if demo{next.highQuality=song.highQuality}
            next.originalModName=mod?.name ?? "Reborn² Standard";next.embeddedMod=mod?.archiveData
            try ensureSamples(next);song=next;applied=nil;sync()
        }catch{self.error=error.localizedDescription}
    }
    func openMod(_ url:URL) {
        do {
            let mod=try RebornSoundPack.read(Data(contentsOf:url))
            if !availableMods.contains(where:{$0.name==mod.name}) {availableMods.append(mod)}
            selectMod(mod)
        }catch{self.error=error.localizedDescription}
    }
    let dsp: OpaquePointer
    private let audio = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var timer: Timer?
    private var applied: Song?
    init() {
        dsp = rb_create()!
        do {
            try Self.loadSamples(dsp)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let target = dsp
            let node = AVAudioSourceNode(format: format) { _, _, frames, list in
                let buffers = UnsafeMutableAudioBufferListPointer(list)
                guard buffers.count == 2, let l = buffers[0].mData, let r = buffers[1].mData else { return kAudio_ParamError }
                rb_render(target, l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self), frames)
                return noErr
            }
            source = node
            audio.attach(node)
            audio.connect(node, to: audio.mainMixerNode, format: format)
            audio.prepare()
            sync()
            try audio.start()
        } catch { self.error = error.localizedDescription }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let tick=Int(rb_tick(self.dsp)), step=Int(rb_current_step(self.dsp))
            let steps=(0..<4).map{Int(rb_current_device_step(self.dsp,Int32($0)))}
            let patterns=(0..<4).map{Int(rb_current_pattern(self.dsp,Int32($0)))}
            let controllers=(0..<9).map{d in (0..<32).map{p in Int(rb_controller(self.dsp,Int32(d),Int32(p)))}}
            let peak=rb_peak(self.dsp)
            let changed=self.currentTick/768 != tick/768 || self.currentStep != step || self.deviceSteps != steps || self.devicePatterns != patterns || self.liveControllers != controllers || abs(self.peak-peak)>0.025 || (peak==0 && self.peak != 0)
            if changed {self.objectWillChange.send()}
            // Publish only changes; a stopped rack no longer redraws thirty times a second.
            if self.currentTick/768 != tick/768 {self.currentTick=tick}
            if self.currentStep != step {self.currentStep=step}
            if self.deviceSteps != steps {self.deviceSteps=steps}
            if self.devicePatterns != patterns {self.devicePatterns=patterns}
            if self.liveControllers != controllers {self.liveControllers=controllers}
            if abs(self.peak-peak)>0.025 || (peak==0 && self.peak != 0) {self.peak=peak}
        }
        if CommandLine.arguments.contains("--record-check") {
            song.events=[SongEvent(tick:48,device:1,parameter:3,value:95)]
            toggleRecording()
            Timer.scheduledTimer(withTimeInterval:0.35,repeats:false){[weak self] _ in guard let self else{return};self.changeController(1,3,64){self.song.bass[0].controls[1]=64}}
            Timer.scheduledTimer(withTimeInterval:0.55,repeats:false){[weak self] _ in
                guard let self else{return};self.finishRecording()
                do {
                    let saved=try RebornSongFile.read(RebornSongFile.write(self.song))
                    let events=saved.events ?? []
                    guard self.error==nil,self.song.valid,events.contains(where:{$0.device==1 && $0.parameter==3 && $0.value==95}),events.contains(where:{$0.device==1 && $0.parameter==3 && $0.value==64}),self.song.bass[0].controls[1]==64,rb_faults(self.dsp)==0 else{throw NSError(domain:"Reborn",code:5)}
                    print("RECORD_CHECK_PASS: controller recorded, initial state retained, RBS round-trip")
                }catch{print("RECORD_CHECK_FAIL: \(error)")}
                fflush(stdout);self.audio.stop();NSApplication.shared.terminate(nil)
            }
        }
        if CommandLine.arguments.contains("--low-check"){song.highQuality=false}
        if CommandLine.arguments.contains("--audio-check") {
            do {
                let encoded=try JSONEncoder().encode(song)
                let decoded=try JSONDecoder().decode(Song.self,from:encoded)
                var legacy=try JSONSerialization.jsonObject(with:encoded) as! [String:Any]
                legacy.removeValue(forKey:"rack");legacy["version"]=1
                let old=try JSONDecoder().decode(Song.self,from:JSONSerialization.data(withJSONObject:legacy))
                guard decoded==song && decoded.valid && old.valid && old.rack==nil && old.effectiveRack.valid else {throw NSError(domain:"Reborn",code:3)}
                print("SONG_CHECK_PASS: rack round-trip and legacy migration")
                var rack=EffectSettings();rack.distorted[0]=true;rack.distortion[2]=20;rack.pcfTarget=2;rack.compressorTarget=1;rack.sends[0]=80
                song.rack=rack
            }catch {self.error="Song-Prüfung fehlgeschlagen: \(error)"}
            
            togglePlayback()
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                guard let self else { return }
                let passed = self.error==nil && rb_faults(self.dsp)==0 && self.audio.isRunning && rb_peak(self.dsp).isFinite && rb_peak(self.dsp) > 0
                print(passed ? "AUDIO_CHECK_PASS" : "AUDIO_CHECK_FAIL: \(self.error ?? "no callback signal")")
                fflush(stdout)
                self.audio.stop()
                NSApplication.shared.terminate(nil)
            }
        }
    }
    deinit { timer?.invalidate(); audio.stop(); rb_destroy(dsp) }
    private static func loadSamples(_ engine:OpaquePointer,mod:RebornSoundPack?=nil)throws {
        let defaults=try defaultSamples()
        try RebornSampleBank(try mod?.samples(fallback:defaults) ?? defaults).commit(to:engine)
    }
    func sync() {
        if applied == song {return}
        guard song.valid else {error="Ungültige Song-Einstellungen.";return}
        do {try ensureSamples(song)}catch{self.error=error.localizedDescription;return}
        if recording,let old=applied {
            let changes=song.controllerChanges(from:old,at:Int(rb_tick(dsp)))
            if (recordBase?.events?.count ?? 0)+recordedEvents.count+changes.count>32768{finishRecording();error="Aufnahmegrenze erreicht.";return}
            recordedEvents += changes
        }
        if song.apply(to:dsp,previous:applied){applied=song}else{error="Audio-Einstellungen konnten nicht vollständig übernommen werden.";applied=nil}
    }
    lazy var bundledSongs:[URL] = {
        let urls=Bundle.main.urls(forResourcesWithExtension:"rbs",subdirectory:"Songs") ?? Bundle.main.urls(forResourcesWithExtension:"rbs",subdirectory:"Songs") ?? []
        return urls.map{$0 as URL}.sorted{$0.lastPathComponent<$1.lastPathComponent}
    }()
    func openSong(_ url:URL) {
        if recording{finishRecording()}
        do {
            var new:Song
            if url.pathExtension.lowercased()=="rbs"{new=try RebornSongFile.read(url);new.highQuality=song.highQuality}else{new=try JSONDecoder().decode(Song.self,from:Data(contentsOf:url))}
            guard new.valid else{throw NSError(domain:"Reborn",code:2,userInfo:[NSLocalizedDescriptionKey:"Ungültige Song-Datei."])}
            if playing{_ = rb_parameter(dsp,4,0,0);playing=false}
            try ensureSamples(new)
            song=new;song.rack=new.effectiveRack;song.version=3;applied=nil;sync()
        }catch{self.error=error.localizedDescription}
    }
    func togglePlayback() {
        if playing && recording{finishRecording();return}
        do {
            try ensureSamples(song)
            if !audio.isRunning { try audio.start() }
            if !playing { applied = nil; sync() }
            guard rb_parameter(dsp,4,0,playing ? 0 : 1) == 1 else { return }
            playing.toggle()
            if !playing { applied = nil;heldNotes=[[],[]] }
        } catch { self.error = "Audioausgabe: \(error.localizedDescription)" }
    }
    func liveValue(_ device:Int,_ parameter:Int)->Double? {
        guard playing,(song.songMode ?? false),device>=0,device<9,parameter>=0,parameter<32,liveControllers[device][parameter]>=0 else{return nil}
        return Double(liveControllers[device][parameter])
    }
    func live(_ value:Binding<Double>,device:Int,parameter:Int,scale:Double=1,offset:Double=0)->Binding<Double> {
        Binding(get:{self.liveValue(device,parameter).map{$0*scale+offset} ?? value.wrappedValue},set:{new in self.changeController(device,parameter,Int(((new-offset)/scale).rounded())){value.wrappedValue=new}})
    }
    func drumControl(device:Int,parameter:Int)->Binding<Double> {
        Binding(get:{
            if let live=self.liveValue(device+3,parameter){return live}
            if let lane=DrumDefinitions.levels[device].firstIndex(of:parameter){
                return self.song.drums[device].voices[device==1 && parameter==22 ? 8:lane].level*127
            }
            return self.song.drums[device].controls?[parameter] ?? DrumDefinitions.defaults(device)[parameter]
        },set:{value in
            self.changeController(device+3,parameter,Int(value.rounded())){
                if self.song.drums[device].controls==nil{self.song.drums[device].controls=DrumDefinitions.defaults(device)}
                self.song.drums[device].controls![parameter]=value
                for lane in 0..<11 where DrumDefinitions.levels[device][lane]==parameter{
                    self.song.drums[device].voices[lane].level=value/127
                }
            }
        })
    }
    func changeController(_ device:Int,_ parameter:Int,_ value:Int,edit:()->Void) {
        let target=ControllerTarget(device,parameter);if lastTouchedController != target{lastTouchedController=target}
        let was=song.controllers[device][parameter],live=Int(rb_controller(dsp,Int32(device),Int32(parameter)))
        edit();sync()
        if recording,was==value,live != value,(recordBase?.events?.count ?? 0)+recordedEvents.count<32768 {
            let tick=min(100_000_000,((Int(rb_tick(dsp))+12)/24)*24)
            recordedEvents.append(SongEvent(tick:tick,device:device,parameter:parameter,value:value))
        }
        _ = rb_set_controller(dsp,Int32(device),Int32(parameter),Int32(value))
    }
    func seek(_ tick:Int) {heldNotes=[[],[]];_ = rb_seek(dsp,Int32(min(100_000_000,max(0,tick))))}
    func toggleRecording() {
        if recording{finishRecording();return}
        if playing{togglePlayback()}
        recordBase=song;recordedEvents=[];recordedNotes=[];pendingRecordedNotes=[:];suppressHistory=true;song.songMode=true;song.looping=false;applied=nil;sync()
        recording=true;togglePlayback()
        if !playing{recording=false;recordBase=nil;suppressHistory=false}
    }
    func finishRecording() {
        guard var result=recordBase else{recording=false;return}
        let tick=Int(rb_tick(dsp));for (key,pending) in pendingRecordedNotes{let parts=key.split(separator:":").compactMap{Int($0)};if parts.count==2,recordedNotes.count<16384{recordedNotes.append(RecordedNote(tick:pending.tick,device:parts[0],note:parts[1],velocity:pending.velocity,duration:max(1,tick-pending.tick)))}};pendingRecordedNotes=[:];recording=false;_ = rb_parameter(dsp,4,0,0);playing=false;heldNotes=[[],[]]
        for d in 0..<2{result.bass[d].patterns=song.bass[d].patterns;result.drums[d].patterns=song.drums[d].patterns}
        result.events=((result.events ?? [])+recordedEvents).enumerated().sorted{a,b in a.element.tick==b.element.tick ? a.offset<b.offset:a.element.tick<b.element.tick}.map(\.element)
        result.songMode=true;result.loopEnd=max(result.loopEnd ?? 768,((tick/768)+1)*768)
        result.midiNotes=((result.midiNotes ?? [])+recordedNotes).sorted{$0.tick<$1.tick}
        history.record(recordBase!,after:result,label:"Aufnahme")
        song=result;suppressHistory=false;recordBase=nil;recordedEvents=[];recordedNotes=[];applied=nil;sync()
    }
    func configureMIDI() {
        if !midiEnabled{_ = rb_midi_sync(dsp,0);midi=nil;heldNotes=[[],[]];for d in 0..<2{_ = rb_live_note(dsp,Int32(d),0,0,0,0)};return}
        do{midi=try RebornMIDI{[weak self] messages in self?.handleMIDIInput(messages)};configureClock()}catch{self.error="MIDI: \(error.localizedDescription)";midiEnabled=false}
    }
    func handleMIDI(_ messages:[MIDIMessage]) {
        guard midiEnabled else{return}
        for message in messages {
            let status=message.status,channel=status&15,type=status&0xf0
            if status==0xfa{if playing{togglePlayback()};togglePlayback();continue}
            if status==0xfb{if !playing{togglePlayback()};continue}
            if status==0xfc{if playing{togglePlayback()};continue}
            if channel<2 && (type==0x90 || type==0x80),message.first<=95 {
                let wasHeld = !heldNotes[channel].isEmpty
                heldNotes[channel].removeAll{$0.note==message.first}
                if type==0x90 && message.second>0{heldNotes[channel].append((message.first,message.second))}
                if let note=heldNotes[channel].last{_ = rb_live_note(dsp,Int32(channel),Int32(note.note),1,note.velocity>=96 ? 1:0,wasHeld ? 1:0)}else{_ = rb_live_note(dsp,Int32(channel),0,0,0,0)}
            }else if [9,10].contains(channel),type==0x90,message.second>0 {
                let machine=channel-9
                let map=machine==0 ? [36:0,38:1,40:1,45:2,47:3,50:4,37:5,39:6,56:7,49:8,46:9,42:10]:[36:0,38:1,40:1,45:2,47:3,50:4,37:5,39:6,42:7,46:8,49:9,51:10]
                if let lane=map[message.first]{_ = rb_live_drum(dsp,Int32(machine),Int32(lane),Float(message.second)/127,0,message.second>=96 ? 1:0)}
            }else if type==0xb0,channel<2 {
                if (20...25).contains(message.first){changeController(channel+1,message.first-18,message.second){song.bass[channel].controls[message.first-20]=Double(message.second)}}
                else if message.first==26{let v=message.second>=64 ? 1:0;changeController(channel+1,8,v){song.bass[channel].controls[6]=Double(v)}}
                else if message.first==7{changeController(0,6+6*channel,message.second){song.bass[channel].level=Double(message.second)/127}}
                else if message.first==10{changeController(0,7+6*channel,message.second){song.bass[channel].pan=Double(message.second)/63.5-1}}
                else if message.first==120 || message.first==123{heldNotes[channel]=[];_ = rb_live_note(dsp,Int32(channel),0,0,0,0)}
            }
        }
        sync()
    }
    func save() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Reborn Song.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(song).write(to: url, options: .atomic) } catch { self.error = error.localizedDescription }
    }
    func saveRBS() {
        do {
            let data=try RebornSongFile.write(song)
            let panel=NSSavePanel();panel.allowedContentTypes=[UTType(filenameExtension:"rbs") ?? .data];panel.nameFieldStringValue="Reborn Song.rbs"
            guard panel.runModal() == .OK,let url=panel.url else{return}
            try data.write(to:url,options:.atomic)
        }catch{self.error=error.localizedDescription}
    }
    func load() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[.json,UTType(filenameExtension:"rbs") ?? .data,UTType(filenameExtension:"rbrpack") ?? .data];panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let url=panel.url else{return};if url.pathExtension.lowercased()=="rbrpack"{openMod(url)}else{openSong(url)}
    }
    func exportAudio() {
        let mod:RebornSoundPack?
        do{mod=try resolveMod(song)}catch{self.error=error.localizedDescription;return}
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.nameFieldStringValue = "Reborn Loop.wav"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let snapshot = song
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let defaults=try Self.defaultSamples()
                try RebornAudioFile.write(snapshot,samples:try mod?.samples(fallback:defaults) ?? defaults,to:url)
            } catch { DispatchQueue.main.async { self.error = "WAV-Export: \(error.localizedDescription)" } }
        }
    }
}

struct RackView:View {
    @ObservedObject var studio:Studio
    @AppStorage("rackZoom") private var zoom=1.25
    @AppStorage("rackZoomRevision") private var zoomRevision=0
    var body:some View {
        GeometryReader{geometry in
            let scale=min(geometry.size.width/592,geometry.size.height/510)
            OriginalRack(studio:studio).environment(\.rackSkin,studio.useModSkin ? studio.modSkin:nil).scaleEffect(scale,anchor:.topLeading)
                .frame(width:592*scale,height:510*scale,alignment:.topLeading)
        }.overlay(RackViewport().allowsHitTesting(false)).frame(minWidth:592,minHeight:510).clipped().background(RackWindow(zoom:zoom,revision:zoomRevision)).preferredColorScheme(.light)
        .onAppear{
            if let url=Bundle.main.url(forResource:"AppIcon",withExtension:"icns"),let icon=NSImage(contentsOf:url){NSApplication.shared.applicationIconImage=icon}
            if CommandLine.arguments.contains("--feature-check"){DispatchQueue.main.asyncAfter(deadline:.now()+0.3){Task{await CreativeFeatureCheck.run(studio)}}}
            if CommandLine.arguments.contains("--ui-check") {
                DispatchQueue.main.asyncAfter(deadline:.now()+0.3){Task{await RackUICheck.run(studio)}}
            }
        }
        .onChange(of:studio.song){_ in studio.sync()}

        .alert("Reborn²",isPresented:Binding(get:{studio.error != nil},set:{if !$0{studio.error=nil}})){Button("OK"){studio.error=nil}}message:{Text(studio.error ?? "")}
    }
}
@main struct RebornApplication:App {
    @StateObject private var studio=Studio()
    var body:some Scene {
        WindowGroup("Reborn²"){RackView(studio:studio)}.defaultSize(width:740,height:638).windowStyle(.titleBar)
            .commands{RebornCommands(studio:studio)}
        Window("Presets",id:"presets"){PresetPanel(studio:studio,library:studio.presets)}.defaultSize(width:700,height:470)
        Window("Song-Editor",id:"song-editor"){SongEditor(studio:studio)}.defaultSize(width:960,height:600)
        Window("Klangvergleich",id:"comparison"){ComparisonPanel(studio:studio)}.defaultSize(width:740,height:520)
        Window("MIDI",id:"midi"){MIDIPanel(studio:studio)}.defaultSize(width:740,height:490)
    }
}
