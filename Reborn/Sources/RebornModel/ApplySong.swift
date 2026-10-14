import RebornDSP

extension Song {
    @discardableResult public func apply(to engine:OpaquePointer,previous old:Song?=nil)->Bool {
        guard valid else{return false};var accepted=true
        func take(_ result:Int32){if result==0{accepted=false}}
        func parameter(_ d:Int,_ p:Int,_ v:Double){take(rb_parameter(engine,Int32(d),Int32(p),Float(v)))}
        if old==nil || old?.highQuality != highQuality{take(rb_quality(engine,(highQuality ?? true) ? 1:0))}
        if old?.tempo != tempo{parameter(4,1,tempo)}
        if old?.swing != swing{parameter(4,8,swing)}
        if old?.master != master{parameter(4,2,master)}
        if old?.effectiveRack != effectiveRack{if !effectiveRack.apply(to:engine){accepted=false}}
        for d in 0..<2 {
            let b=bass[d],before=old?.bass[d]
            for i in 0..<7 where before?.controls[i] != b.controls[i]{parameter(d,i+2,i==6 ? (b.controls[i]>0.5 ? 1:0):b.controls[i])}
            if before?.level != b.level{parameter(d,20,b.level)}
            if before?.pan != b.pan{parameter(d,21,b.pan)}
            if before?.channelEnabled != b.channelEnabled{take(rb_channel_enabled(engine,Int32(d),b.channelEnabled ? 1:0))}
            if before?.selectedPattern != b.selectedPattern || before?.enabled != b.enabled{take(rb_pattern_select(engine,Int32(d),Int32(b.selectedPattern),b.enabled ? 1:0))}
            for pattern in 0..<32 {
                let p=b.patterns[pattern],prior=before?.patterns[pattern]
                if prior == p {continue}
                if prior?.length != p.length || prior?.shuffled != p.shuffled{take(rb_pattern_meta(engine,Int32(d),Int32(pattern),Int32(p.length),p.shuffled ? 1:0))}
                for step in 0..<16 where prior?.steps[step] != p.steps[step]{let n=p.steps[step];take(rb_note_pattern_step(engine,Int32(d),Int32(pattern),Int32(step),Int32(n.note),n.enabled ? 1:0,n.accent ? 1:0,n.slide ? 1:0))}
            }
            let drum=drums[d],beforeDrum=old?.drums[d]
            if beforeDrum?.level != drum.level{parameter(d+2,20,drum.level)}
            if beforeDrum?.pan != drum.pan{parameter(d+2,21,drum.pan)}
            let controls=drum.controls ?? DrumDefinitions.defaults(d),prior=beforeDrum?.controls ?? DrumDefinitions.defaults(d)
            for id in controls.indices where !DrumDefinitions.levels[d].contains(id) && id>1 {
                if old==nil || prior[id] != controls[id]{take(rb_drum_parameter(engine,Int32(d),Int32(id),Int32(controls[id].rounded())))}
            }
            if beforeDrum?.channelEnabled != drum.channelEnabled{take(rb_channel_enabled(engine,Int32(d+2),drum.channelEnabled ? 1:0))}
            if beforeDrum?.selectedPattern != drum.selectedPattern || beforeDrum?.enabled != drum.enabled{take(rb_pattern_select(engine,Int32(d+2),Int32(drum.selectedPattern),drum.enabled ? 1:0))}
            for lane in 0..<11 {
                let v=drum.voices[lane];let level=(d==1&&lane==7) ? drum.voices[8].level:v.level
                let beforeLevel=(d==1&&lane==7) ? beforeDrum?.voices[8].level:beforeDrum?.voices[lane].level
                if beforeLevel != level{take(rb_drum_parameter(engine,Int32(d),Int32(DrumDefinitions.levels[d][lane]),Int32((level*127).rounded())))}
                if beforeDrum?.voices[lane].sample != v.sample{take(rb_sample(engine,Int32(d),Int32(lane),Int32(v.sample)))}
            }
            for pattern in 0..<32 {
                let p=drum.patterns[pattern],previous=beforeDrum?.patterns[pattern]
                if previous == p {continue}
                if previous?.length != p.length || previous?.shuffled != p.shuffled{take(rb_pattern_meta(engine,Int32(d+2),Int32(pattern),Int32(p.length),p.shuffled ? 1:0))}
                for step in 0..<16 where previous?.accents[step] != p.accents[step]{take(rb_drum_pattern_accent(engine,Int32(d),Int32(pattern),Int32(step),p.accents[step] ? 1:0))}
                for lane in 0..<11 {for step in 0..<16 {
                    let h=p.hits[lane],last=previous?.hits[lane]
                    if last?.steps[step] != h.steps[step] || last?.strong[step] != h.strong[step] || last?.flam[step] != h.flam[step] {
                        let strength=h.steps[step] ? (h.strong[step] ? 2:1)+(h.flam[step] ? 2:0):0
                        take(rb_drum_pattern_step(engine,Int32(d),Int32(pattern),Int32(lane),Int32(step),Int32(strength)))
                    }
                }}
            }
        }
        if old==nil || old?.events != events {take(rb_song_clear(engine));for e in events ?? []{take(rb_song_event(engine,Int32(e.tick),Int32(e.device),Int32(e.parameter),Int32(e.value)))}}
        if old==nil || old?.events != events || old?.songMode != songMode || old?.loopStart != loopStart || old?.loopEnd != loopEnd || old?.looping != looping {
            take(rb_song_mode(engine,(songMode ?? false) ? 1:0,Int32(loopStart ?? 0),Int32(loopEnd ?? 768),(looping ?? false) ? 1:0))
        }
        if old==nil || old?.midiNotes != midiNotes {
            take(rb_song_notes_clear(engine))
            var notes=[(tick:Int,device:Int,note:Int,velocity:Int,on:Int)]()
            for note in midiNotes ?? []{notes.append((note.tick,note.device,note.note,note.velocity,1));if note.device<2{notes.append((note.tick+note.duration,note.device,note.note,note.velocity,0))}}
            notes.sort{a,b in a.tick==b.tick ? a.on<b.on:a.tick<b.tick}
            for note in notes{take(rb_song_note_event(engine,Int32(note.tick),Int32(note.device),Int32(note.note),Int32(note.velocity),Int32(note.on)))}
        }
        let initial=controllers,before=old?.controllers
        let refresh=old==nil || old?.events != events || old?.songMode != songMode || old?.loopStart != loopStart || old?.loopEnd != loopEnd || old?.looping != looping
        for d in 0..<9{for p in 0..<32 where initial[d][p]>=0 && (refresh || before?[d][p] != initial[d][p]){take(rb_song_baseline(engine,Int32(d),Int32(p),Int32(initial[d][p])))}}
        return accepted
    }
}
