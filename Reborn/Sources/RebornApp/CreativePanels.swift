import SwiftUI
import RebornModel

struct PresetPanel:View {
    @ObservedObject var studio:Studio
    @ObservedObject var library:PresetLibrary
    @State private var selected:UUID?
    @State private var name=""
    @State private var search=""
    @State private var kind=PresetKind.bassSound
    private var matches:[RebornPreset]{library.entries.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)}.filter{$0.kind==kind}}
    private var chosen:RebornPreset?{matches.first{$0.id==selected}}
    private var devices:[Int]{[.bassSound,.bassPattern].contains(kind) ? [0,1]:[.drumKit,.drumPattern].contains(kind) ? [2,3]:[0,1,2,3]}
    var body:some View {
        VStack(spacing:12){
            HStack{Picker("Typ",selection:$kind){ForEach(PresetKind.allCases){kind in Text(kind.title).tag(kind)}};Picker("Ziel",selection:$studio.presetDevice){ForEach(devices,id:\.self){d in Text(["303 · 1","303 · 2","808","909"][d]).tag(d)}};TextField("Suchen",text:$search)}
            List(matches,selection:$selected){preset in HStack{Text(preset.name);Spacer();Text(preset.factory ? "Werk":"Eigene").font(.caption).foregroundStyle(.secondary)}.tag(preset.id)}
            if let problem=library.problem{Text(problem).font(.caption).foregroundStyle(.red)}
            HStack{TextField("Preset-Name",text:$name);Button("Aktuellen Stand speichern"){studio.savePreset(name:name,kind:kind,device:studio.presetDevice)}.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || studio.recording)}
            HStack{Button("Importieren",action:studio.importPreset);Button("Exportieren"){if let preset=chosen{studio.exportPreset(preset)}}.disabled(chosen==nil);Button("Umbenennen"){if let preset=chosen{do{try library.rename(preset.id,name)}catch{studio.error=error.localizedDescription}}}.disabled(chosen?.factory != false || name.isEmpty);Button("Löschen"){if let preset=chosen{do{try library.delete(preset.id)}catch{studio.error=error.localizedDescription}}}.disabled(chosen?.factory != false);Spacer();Button("Laden"){if let preset=chosen{studio.applyPreset(preset,device:studio.presetDevice)}}.disabled(chosen==nil || studio.recording).keyboardShortcut(.defaultAction)}
        }.padding(16).frame(minWidth:660,minHeight:450).onAppear{if studio.presetDevice>=2{kind = .drumKit}}.onChange(of:selected){id in let preset=library.entries.first{$0.id==id};name=preset?.name ?? "";if preset?.kind == .drumKit,let device=preset?.drumDevice{studio.presetDevice=device+2}}.onChange(of:kind){type in selected=nil;if [.bassSound,.bassPattern].contains(type){studio.presetDevice=min(1,studio.presetDevice)}else if [.drumKit,.drumPattern].contains(type){studio.presetDevice=max(2,studio.presetDevice)}}
    }
}
struct SongEditor:View {
    @ObservedObject var studio:Studio
    @State private var bars=16
    @State private var bar=0
    @State private var arrangement=[[Int]](repeating:[],count:4)
    @State private var selectedEvent:Int?
    @State private var selectedNote:UUID?
    @State private var target=ControllerTarget(1,3)
    @State private var eventTick=0
    @State private var eventValue=64
    @State private var noteTick=0
    @State private var noteDevice=0
    @State private var notePitch=48
    @State private var noteVelocity=100
    @State private var noteLength=48
    private var events:[SongEvent]{studio.song.events ?? []}
    private var notes:[RecordedNote]{studio.song.midiNotes ?? []}
    private var basePatterns:[Int]{studio.song.bass.map(\.selectedPattern)+studio.song.drums.map(\.selectedPattern)}
    private func rebuildArrangement(){
        let timeline=events
        var selected=basePatterns,index=0,rows=[[Int]](repeating:[],count:4)
        for bar in 0..<bars{
            while index<timeline.count && timeline[index].tick<=bar*768{let event=timeline[index];if (1...4).contains(event.device) && event.parameter==1{selected[event.device-1]=min(31,max(0,event.value))};index+=1}
            for device in 0..<4{rows[device].append(selected[device])}
        }
        arrangement=rows
    }
    private func patternName(_ p:Int)->String{let value=min(31,max(0,p));return ["A","B","C","D"][value/8]+"\(value%8+1)"}
    private func saveEvent(){studio.editSong("Automation bearbeiten"){next in var values=next.events ?? [];let event=SongEvent(tick:eventTick,device:target.device,parameter:target.parameter,value:min(target.range.upperBound,max(target.range.lowerBound,eventValue)));if let index=selectedEvent,values.indices.contains(index){values[index]=event}else{values.append(event)};next.events=values.sorted{$0.tick<$1.tick};next.songMode=true;next.loopEnd=max(next.loopEnd ?? 768,(eventTick/768+1)*768)};selectedEvent=nil}
    private func saveNote(){studio.editSong("MIDI-Note bearbeiten"){next in var values=next.midiNotes ?? [];let note=RecordedNote(tick:noteTick,device:noteDevice,note:notePitch,velocity:noteVelocity,duration:noteLength);if let id=selectedNote,let index=values.firstIndex(where:{$0.id==id}){var updated=note;updated.id=id;values[index]=updated}else{values.append(note)};next.midiNotes=values.sorted{$0.tick<$1.tick};next.songMode=true;next.loopEnd=max(next.loopEnd ?? 768,((noteTick+noteLength)/768+1)*768)}}
    var body:some View {
        VStack(spacing:10){
            HStack{Toggle("Song-Modus",isOn:Binding(get:{studio.song.songMode ?? false},set:{value in studio.editSong("Song-Modus"){$0.songMode=value}}));Stepper("\(bars) Takte",value:$bars,in:1...128);Spacer();Picker("Takt",selection:$bar){ForEach(0..<bars,id:\.self){n in Text("\(n+1)").tag(n)}}.frame(width:100);Button("Springen"){studio.seek(bar*768)};Button("Einfügen"){studio.insertBar(bar);bars=min(128,bars+1)};Button("Duplizieren"){studio.duplicateBar(bar);bars=min(128,bars+1)};Button("Entfernen"){studio.removeBar(bar);bars=max(1,bars-1);bar=min(bar,bars-1)}}
            ScrollView(.horizontal){VStack(spacing:4){HStack{Text("Gerät").frame(width:60);ForEach(0..<bars,id:\.self){b in Text("\(b+1)").font(.caption.monospaced()).frame(width:55)}};ForEach(0..<4,id:\.self){d in HStack{Text(["303 · 1","303 · 2","808","909"][d]).frame(width:60);ForEach(0..<bars,id:\.self){b in Menu(patternName(arrangement[d].indices.contains(b) ? arrangement[d][b]:basePatterns[d])){ForEach(0..<32,id:\.self){p in Button(patternName(p)){studio.setPattern(bar:b,device:d,pattern:p)}}}.frame(width:55).background(studio.currentTick/768==b && studio.playing ? Color.orange.opacity(0.2):.clear)}}}}}.frame(height:150)
            TabView{
                HSplitView{
                    List(events.indices,id:\.self,selection:$selectedEvent){i in HStack{Text("\(events[i].tick/768+1):\(events[i].tick%768)").monospacedDigit();Text(ControllerTarget(events[i].device,events[i].parameter).label);Spacer();Text("\(events[i].value)")}.tag(i)}
                    VStack(alignment:.leading,spacing:10){Text("Automation").font(.headline);TextField("Tick",value:$eventTick,format:.number);Picker("Regler",selection:$target){ForEach(ControllerTarget.all){t in Text(t.label).tag(t)}};Stepper("Wert: \(eventValue)",value:$eventValue,in:target.range);Button("Neu"){selectedEvent=nil};Button("Speichern",action:saveEvent);Button("Löschen"){if let i=selectedEvent{studio.editSong("Automation löschen"){next in if next.events?.indices.contains(i)==true{next.events!.remove(at:i)}};selectedEvent=nil}}.disabled(selectedEvent==nil);Spacer()}.padding().frame(width:280)
                }.tabItem{Text("Automation")}
                HSplitView{
                    List(notes,selection:$selectedNote){note in HStack{Text("Takt \(note.tick/768+1)");Text(["303 · 1","303 · 2","808","909"][note.device]);Text("\(note.note)");Spacer();Text("\(note.duration) Ticks")}.tag(note.id)}
                    ScrollView{VStack(alignment:.leading,spacing:10){Text("MIDI-Noten").font(.headline);Picker("Gerät",selection:$noteDevice){ForEach(0..<4,id:\.self){d in Text(["303 · 1","303 · 2","808","909"][d]).tag(d)}};TextField("Tick",value:$noteTick,format:.number);Stepper("Note/Stimme: \(notePitch)",value:$notePitch,in:0...(noteDevice<2 ? 95:10));Stepper("Velocity: \(noteVelocity)",value:$noteVelocity,in:1...127);TextField("Länge (Ticks)",value:$noteLength,format:.number);Button("Neu"){selectedNote=nil};Button("Speichern",action:saveNote);Button("Löschen"){if let id=selectedNote{studio.editSong("MIDI-Note löschen"){$0.midiNotes?.removeAll{$0.id==id}};selectedNote=nil}}.disabled(selectedNote==nil);Spacer()}.padding()}.frame(width:280)
                }.tabItem{Text("MIDI-Noten")}
            }
            Text("768 Ticks = 1 Takt · 48 Ticks = 1 Schritt. MIDI-Noten bleiben im nativen JSON-Song und WAV erhalten.").font(.caption).foregroundStyle(.secondary)
        }.padding(12).frame(minWidth:900,minHeight:560).disabled(studio.recording)
        .onAppear{bars=min(128,max(16,(studio.song.loopEnd ?? 768)/768));rebuildArrangement()}
        .onChange(of:selectedEvent){i in if let i,events.indices.contains(i){let e=events[i];target=ControllerTarget(e.device,e.parameter);eventTick=e.tick;eventValue=e.value}}
        .onChange(of:selectedNote){id in if let note=notes.first(where:{$0.id==id}){noteTick=note.tick;noteDevice=note.device;notePitch=note.note;noteVelocity=note.velocity;noteLength=note.duration}}
        .onChange(of:noteDevice){d in notePitch=min(notePitch,d<2 ? 95:10)}
        .onChange(of:bars){count in bar=min(bar,count-1);rebuildArrangement()}
        .onChange(of:studio.song.events){_ in selectedEvent=nil;rebuildArrangement()}
        .onChange(of:basePatterns){_ in rebuildArrangement()}
    }
}
struct MIDIPanel:View {
    @ObservedObject var studio:Studio
    @State private var target=ControllerTarget(1,3)
    @State private var sources=RebornMIDI.availableSources
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack{Toggle("MIDI-Eingang",isOn:$studio.midiEnabled);Button("Quellen aktualisieren"){sources=RebornMIDI.availableSources};Spacer()}
            Toggle("Externe MIDI-Clock (24 Pulse pro Viertelnote)",isOn:$studio.midiClockEnabled)
            Picker("Clock-Quelle",selection:$studio.clockSource){Text("Automatisch").tag(Int32(0));ForEach(sources){source in Text(source.name).tag(source.id)}}
            Text(studio.clockTempo.map{"Clock: \($0.formatted(.number.precision(.fractionLength(1)))) BPM"} ?? "Warte auf MIDI-Clock").font(.caption)
            Divider();Text("MIDI-Learn").font(.headline)
            Picker("Zielregler",selection:$target){ForEach(ControllerTarget.all){target in Text(target.label).tag(target)}}
            HStack{Button("Zuletzt bewegten Regler wählen"){if let last=studio.lastTouchedController{target=last}}.disabled(studio.lastTouchedController==nil);Button("Lernen"){studio.beginLearn(target)};Spacer()}
            if let pending=studio.learnTarget{HStack{Text("Warte auf CC für "+pending.label).font(.caption);Spacer();Button("Abbrechen"){studio.learnTarget=nil}}}
            List(studio.learnMappings){mapping in HStack{Text("Kanal \(mapping.channel+1) · CC \(mapping.cc)");Text(mapping.target.label);Spacer();Button("Entfernen"){studio.learnMappings.removeAll{$0.id==mapping.id}}}}
            Text("303: Kanal 1/2 · Drums: Kanal 10/11. Der Aufnahme-Knopf zeichnet Noten und Regler auf. Clock Start, Continue, Stop und Song Position werden übernommen.").font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(minWidth:700,minHeight:470)
    }
}
struct RebornCommands:Commands {
    @ObservedObject var studio:Studio
    @Environment(\.openWindow) private var openWindow
    @AppStorage("rackZoom") private var zoom=1.25
    @AppStorage("rackZoomRevision") private var zoomRevision=0
    var body:some Commands {
        CommandGroup(after:.newItem){Button("Song oder Soundpack öffnen",action:studio.load).keyboardShortcut("o");Button("Song sichern",action:studio.save).keyboardShortcut("s");Button("ReBirth-Song (.rbs) sichern",action:studio.saveRBS);Button("WAV exportieren",action:studio.exportAudio)}
        CommandGroup(replacing:.undoRedo){Button("Rückgängig",action:studio.undo).keyboardShortcut("z").disabled(!studio.canUndo);Button("Wiederholen",action:studio.redo).keyboardShortcut("z",modifiers:[.command,.shift]).disabled(!studio.canRedo)}
        CommandMenu("Presets"){Button("Preset-Bibliothek"){openWindow(id:"presets")}.keyboardShortcut("p",modifiers:[.command,.shift])}
        CommandMenu("Song"){Button("Song-Editor"){openWindow(id:"song-editor")}.keyboardShortcut("e");ForEach(studio.bundledSongs,id:\.self){url in Button(url.deletingPathExtension().lastPathComponent){studio.openSong(url)}}}
        CommandMenu("Soundpacks"){Button("Reborn² Standard"){studio.selectMod(nil)};ForEach(studio.availableMods,id:\.name){mod in Menu(mod.name){Button("Klänge laden"){studio.selectMod(mod)};Button("Demo öffnen"){studio.selectMod(mod,demo:true)}}};Toggle("Soundpack-Oberfläche",isOn:$studio.useModSkin)}
        CommandMenu("Ansicht"){Button("100 %"){zoom=1;zoomRevision+=1}.keyboardShortcut("0");ForEach([1.25,1.5,2.0],id:\.self){scale in Button("\(Int(scale*100)) %"){zoom=scale;zoomRevision+=1}};Divider();Button("Vergrößern"){zoom=min(2,zoom+0.25);zoomRevision+=1}.keyboardShortcut("=");Button("Verkleinern"){zoom=max(1,zoom-0.25);zoomRevision+=1}.keyboardShortcut("-")}
        CommandMenu("MIDI"){Button("Clock und MIDI-Learn"){openWindow(id:"midi")};Toggle("MIDI-Eingang",isOn:$studio.midiEnabled);Toggle("Externe Clock",isOn:$studio.midiClockEnabled)}
        CommandMenu("Options"){Button("Klangvergleich mit Original"){openWindow(id:"comparison")};Toggle("303: hohe Qualität",isOn:Binding(get:{studio.song.highQuality ?? true},set:{studio.song.highQuality=$0})).disabled(studio.recording || studio.playing)}
    }
}
