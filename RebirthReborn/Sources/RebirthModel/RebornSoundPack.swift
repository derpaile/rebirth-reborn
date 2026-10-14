import Foundation

/// An open JSON container for artist-created sounds and optional rack skins.
public struct RebornSoundPack {
    public let name:String,files:[String:Data],archiveData:Data
    public var demo:Data?{files["demo.rbs"]}
    public var imageNames:[String]{files.keys.filter{$0.hasSuffix(".jpg") || $0.hasSuffix(".png")}.sorted()}
    public static let sampleNames=(0..<46).map{"voice-\($0).aiff"}
    private struct Archive:Codable{let format:String,name:String,files:[String:Data]}
    public enum ReadError:LocalizedError{case invalid(String);public var errorDescription:String?{if case .invalid(let reason)=self{return "Soundpack: "+reason};return nil}}
    public static func make(name:String,files:[String:Data])throws->RebornSoundPack{
        let archive=Archive(format:"reborn-soundpack-1",name:name,files:files)
        let data=try JSONEncoder().encode(archive);return try read(data)
    }
    public static func read(_ data:Data)throws->RebornSoundPack{
        guard data.count<=32*1024*1024 else{throw ReadError.invalid("Datei zu groß.")}
        let archive=try JSONDecoder().decode(Archive.self,from:data)
        guard archive.format=="reborn-soundpack-1",!archive.name.isEmpty,archive.name.count<=100,archive.files.count<=128,
              archive.files.keys.allSatisfy({!$0.contains("/") && !$0.contains("\\") && !$0.contains("..")}) else{throw ReadError.invalid("Ungültiges Reborn-Soundpack.")}
        return RebornSoundPack(name:archive.name,files:archive.files,archiveData:data)
    }
    public func samples(fallback:[Data])throws->[Data]{guard fallback.count==46 else{throw ReadError.invalid("Samplebank unvollständig.")};return Self.sampleNames.enumerated().map{files[$0.element] ?? fallback[$0.offset]}}
}
