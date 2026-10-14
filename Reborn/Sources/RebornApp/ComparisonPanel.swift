import SwiftUI
import AppKit
import UniformTypeIdentifiers
import RebornModel

struct ComparisonPanel:View {
    @ObservedObject var studio:Studio
    @State private var original:URL?
    @State private var report:AudioComparisonReport?
    @State private var busy=false
    @State private var message=""
    private func choose(){let panel=NSOpenPanel();panel.allowedContentTypes=[.wav];guard panel.runModal() == .OK else{return};original=panel.url;report=nil}
    private func compare(){guard let original else{return};busy=true;message="Vergleiche …";studio.compareAudio(original){result in busy=false;switch result{case .success(let value):report=value;message="Vergleich abgeschlossen";case .failure(let error):message=error.localizedDescription}}}
    private func save(){guard let report else{return};let panel=NSSavePanel();panel.allowedContentTypes=[.json];panel.nameFieldStringValue="Reborn Klangvergleich.json";guard panel.runModal() == .OK,let url=panel.url else{return};do{let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(report).write(to:url,options:.atomic)}catch{message=error.localizedDescription}}
    var body:some View{
        VStack(alignment:.leading,spacing:16){
            Text("Vergleich mit dem Original").font(.title2.bold())
            Text("Denselben Song mit denselben Einstellungen im Original als Stereo-WAV exportieren, dann hier mit dem geladenen Song vergleichen.")
            HStack{Button("Original-WAV wählen",action:choose);Text(original?.lastPathComponent ?? "Kein Originalexport gewählt").foregroundStyle(.secondary)}
            HStack{Button("Vergleichen",action:compare).disabled(original==nil || busy || studio.recording);if busy{ProgressView().controlSize(.small)};Text(message)}
            if let report{Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:12){GridRow{Text("Verglichene Dauer");Text((Double(report.frames)/44100).formatted(.number.precision(.fractionLength(2)))+" s")};GridRow{Text("Zeitversatz");Text("\(report.offsetFrames) Samples")};GridRow{Text("RMS-Abweichung");Text(report.rmsError.formatted(.number.precision(.significantDigits(6))))};GridRow{Text("Maximale Abweichung");Text(report.maxError.formatted(.number.precision(.significantDigits(6))))};GridRow{Text("Relative Abweichung");Text((report.relativeError*100).formatted(.number.precision(.fractionLength(3)))+" %")};GridRow{Text("Korrelation");Text(report.correlation.formatted(.number.precision(.fractionLength(6))))};GridRow{Text("Längen Original / Reborn");Text("\(report.originalFrames) / \(report.nativeFrames) Samples")}};Button("Bericht sichern",action:save)}
            Spacer()
        }.padding(20).frame(minWidth:680,minHeight:450)
    }
}
extension Studio {
    func compareAudio(_ reference:URL,completion:@escaping(Result<AudioComparisonReport,Error>)->Void){
        let snapshot=song,mod:RebornSoundPack?
        do{mod=try resolveMod(song)}catch{completion(.failure(error));return}
        DispatchQueue.global(qos:.userInitiated).async{
            let native=FileManager.default.temporaryDirectory.appendingPathComponent("reborn-compare-\(UUID().uuidString).wav")
            defer{try? FileManager.default.removeItem(at:native)}
            let result=Result{let defaults=try Self.defaultSamples();try RebornAudioFile.write(snapshot,samples:try mod?.samples(fallback:defaults) ?? defaults,to:native);return try AudioComparison.compare(original:reference,native:native)}
            DispatchQueue.main.async{completion(result)}
        }
    }
}
