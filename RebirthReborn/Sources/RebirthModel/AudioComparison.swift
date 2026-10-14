import Foundation
import AVFoundation

public struct AudioComparisonReport:Codable {
    public var frames:Int64,offsetFrames:Int,originalFrames:Int64,nativeFrames:Int64
    public var referenceRMS:Double,rmsError:Double,maxError:Double,relativeError:Double,correlation:Double
}
public enum AudioComparison {
    private static func open(_ url:URL)throws->AVAudioFile{
        let file=try AVAudioFile(forReading:url,commonFormat:.pcmFormatFloat32,interleaved:false)
        guard file.processingFormat.channelCount==2,file.processingFormat.sampleRate==44100 else{throw ComparisonError.format}
        guard file.length>=128 else{throw ComparisonError.short}
        return file
    }
    private static func prefix(_ file:AVAudioFile)throws->[Float]{let n=AVAudioFrameCount(min(file.length,46080));let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:n)!;try file.read(into:buffer,frameCount:n);return (0..<Int(buffer.frameLength)).map{(buffer.floatChannelData![0][$0]+buffer.floatChannelData![1][$0])*0.5}}
    public static func compare(original:URL,native:URL)throws->AudioComparisonReport{
        let a=try open(original),b=try open(native),left=try prefix(a),right=try prefix(b)
        guard left.count>=128,right.count>=128 else{throw ComparisonError.short}
        func score(_ offset:Int,_ stride:Int)->Double{
            let startA=max(0,offset),startB=max(0,-offset),count=min(left.count-startA,right.count-startB,22050)
            guard count>0 else{return -1};var dot=0.0,aa=0.0,bb=0.0
            for i in Swift.stride(from:0,to:count,by:stride){let x=Double(left[startA+i]),y=Double(right[startB+i]);dot+=x*y;aa+=x*x;bb+=y*y}
            return dot/max(1e-20,sqrt(aa*bb))
        }
        var best=0,bestScore=score(0,8)
        for offset in stride(from:-2048,through:2048,by:8){let value=score(offset,8);if value>bestScore+1e-10{best=offset;bestScore=value}}
        let coarse=best
        bestScore=score(coarse,1)
        for offset in max(-2048,coarse-8)...min(2048,coarse+8){let value=score(offset,1);if value>bestScore+1e-10{best=offset;bestScore=value}}
        a.framePosition=Int64(max(0,best));b.framePosition=Int64(max(0,-best))
        let frames=min(a.length-a.framePosition,b.length-b.framePosition)
        guard frames>0 else{throw ComparisonError.short}
        let buffers=[a,b].map{AVAudioPCMBuffer(pcmFormat:$0.processingFormat,frameCapacity:4096)!}
        var remaining=frames,aa=0.0,bb=0.0,ab=0.0,error=0.0,maximum=0.0
        while remaining>0{
            let n=AVAudioFrameCount(min(4096,remaining));try a.read(into:buffers[0],frameCount:n);try b.read(into:buffers[1],frameCount:n)
            for channel in 0..<2{for i in 0..<Int(n){let x=Double(buffers[0].floatChannelData![channel][i]),y=Double(buffers[1].floatChannelData![channel][i]);guard x.isFinite,y.isFinite else{throw ComparisonError.invalid};let difference=x-y;aa+=x*x;bb+=y*y;ab+=x*y;error+=difference*difference;maximum=max(maximum,abs(difference))}}
            remaining-=Int64(n)
        }
        let rms=sqrt(aa/Double(frames*2)),difference=sqrt(error/Double(frames*2))
        return AudioComparisonReport(frames:frames,offsetFrames:best,originalFrames:a.length,nativeFrames:b.length,referenceRMS:rms,rmsError:difference,maxError:maximum,relativeError:rms>1e-12 ? difference/rms:difference,correlation:aa>1e-20 && bb>1e-20 ? ab/sqrt(aa*bb):0)
    }
    public enum ComparisonError:LocalizedError{case format,short,invalid;public var errorDescription:String?{switch self{case .format:return "Bitte Stereo-WAV mit 44.1 kHz verwenden.";case .short:return "Audio-Datei zu kurz.";case .invalid:return "Audio enthält ungültige Werte."}}}
}
