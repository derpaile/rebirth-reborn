import Foundation
import AVFoundation
import RebirthDSP

public enum RebirthAudioFile {
    public static func frameCount(_ song:Song)->Int64 {
        let lastNote=(song.midiNotes ?? []).map{$0.tick+$0.duration}.max() ?? 0
        let ticks=(song.songMode ?? false) ? max(song.loopEnd ?? 768,(max(song.events?.last?.tick ?? 0,lastNote)/768+2)*768):3072
        return Int64(Double(ticks)*44100*60/(song.tempo*192))
    }
    public static func write(_ song:Song,samples:[Data],to url:URL)throws {
        guard song.valid else{throw RebirthSongFile.ReadError.malformed("Ungültiger Song.")}
        let frames=frameCount(song)
        guard frames<=Int64(UInt32.max-4096)/8 else{throw RebirthSongFile.ReadError.malformed("Der Song überschreitet die Größenbegrenzung einer WAV-Datei.")}
        let engine=rb_create()!;defer{rb_destroy(engine)}
        try RebirthSampleBank(samples).commit(to:engine)
        var once=song;once.looping=false
        guard once.apply(to:engine) else{throw RebirthSongFile.ReadError.malformed("Song konnte nicht zum Export übernommen werden.")}
        _ = rb_parameter(engine,4,0,1)
        let temporary=url.deletingLastPathComponent().appendingPathComponent(".rebirth-\(UUID().uuidString).wav")
        defer{try? FileManager.default.removeItem(at:temporary)}
        let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
        // Closing the file before moving it finalizes the WAV header.
        do {
            var settings=format.settings;settings[AVLinearPCMIsNonInterleaved]=false
            let file=try AVAudioFile(forWriting:temporary,settings:settings,commonFormat:.pcmFormatFloat32,interleaved:false)
            let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:4096)!
            var remaining=frames
            while remaining>0 {
                let count=UInt32(min(4096,remaining));buffer.frameLength=count
                rb_render(engine,buffer.floatChannelData![0],buffer.floatChannelData![1],count)
                guard rb_faults(engine)==0 else{throw RebirthSongFile.ReadError.malformed("Ungültiger Audiopegel beim Export.")}
                try file.write(from:buffer);remaining-=Int64(count)
            }
        }
        if FileManager.default.fileExists(atPath:url.path){_ = try FileManager.default.replaceItemAt(url,withItemAt:temporary)}else{try FileManager.default.moveItem(at:temporary,to:url)}
    }
}
