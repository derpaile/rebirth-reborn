import SwiftUI
import RebirthModel

final class PresetLibrary:ObservableObject {
    @Published private(set) var entries=RebirthPreset.builtIn
    @Published var problem:String?
    let directory:URL
    init(directory:URL?=nil){
        self.directory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Rebirth Reborn Community/Presets",isDirectory:true)
        let file=self.directory.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath:file.path){do{let data=try Data(contentsOf:file);guard data.count<=64*1024*1024 else{throw LibraryError.invalid};let saved=try JSONDecoder().decode([RebirthPreset].self,from:data);guard saved.count<=512,saved.allSatisfy(\.valid),Set(saved.map(\.id)).count==saved.count else{throw LibraryError.invalid};entries+=saved.map{var p=$0;p.factory=false;return p}}catch{problem="Preset-Bibliothek konnte nicht geladen werden: \(error.localizedDescription)"}}
    }
    func add(_ preset:RebirthPreset)throws{guard preset.valid,entries.count<523 else{throw LibraryError.invalid};let before=entries;var copy=preset;copy.factory=false;if let index=entries.firstIndex(where:{$0.id==copy.id && !$0.factory}){entries[index]=copy}else{entries.append(copy)};do{try persist()}catch{entries=before;throw error}}
    func rename(_ id:UUID,_ name:String)throws{guard let index=entries.firstIndex(where:{$0.id==id && !$0.factory}) else{return};var copy=entries[index];copy.name=name;guard copy.valid else{throw LibraryError.invalid};let before=entries;entries[index]=copy;do{try persist()}catch{entries=before;throw error}}
    func delete(_ id:UUID)throws{let before=entries;entries.removeAll{$0.id==id && !$0.factory};do{try persist()}catch{entries=before;throw error}}
    func persist()throws{try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);let data=try JSONEncoder().encode(entries.filter{!$0.factory});guard data.count<=64*1024*1024 else{throw LibraryError.invalid};try data.write(to:directory.appendingPathComponent("library.json"),options:.atomic)}
    enum LibraryError:LocalizedError{case invalid;var errorDescription:String?{"Preset ungültig oder Bibliothek voll."}}
}
