import Foundation

/// All 46 mono voices are synthesized from equations and seeded noise at startup.
/// No recordings, external samples, original application files or network calls.
public enum RemakeSoundBank {
    public static let samples:[Data]=(0..<46).map(make)
    private static func make(_ id:Int)->Data {
        let rate=44100.0,frames=Int(rate*(id==22 || id==43 || id>=44 ? 1.8:0.8))
        var seed=UInt32(id+1)&*2654435761,phase=0.0,lastNoise=0.0,pcm=[UInt8]();pcm.reserveCapacity(frames*2)
        let variant=Double(id%5)
        for n in 0..<frames {
            let t=Double(n)/rate
            seed=seed&*1664525&+1013904223
            let noise=Double(seed>>8)/8388607.5-1,high=noise-lastNoise;lastNoise=noise
            var value=0.0
            switch id {
            case 0,25...28:
                let base=id==0 ? 48.0:50+Double(id-25)*5
                phase+=(base+135*exp(-t*48))/rate
                value=sin(phase*2*Double.pi)*exp(-t*(id==0 ? 7:11))+high*exp(-t*400)*0.05
            case 1...5,29...33:
                phase+=(id<6 ? 160+variant*18:180+variant*22)/rate
                value=(sin(phase*2*Double.pi)*0.55+sin(phase*3.8*Double.pi)*0.2)*exp(-t*18)
            case 6...9,34...36:
                value=high*0.35*exp(-t*(12+variant*2))
            case 10:
                value=(sin(t*540*2*Double.pi)>0 ? 0.3:-0.3)+(sin(t*810*2*Double.pi)>0 ? 0.3:-0.3);value*=exp(-t*12)
            case 11,22,42,43:
                let decay=(id==22 || id==43) ? 5.0:50.0
                let metal=sin(t*4093*2*Double.pi)*sin(t*6121*2*Double.pi)
                value=(high*0.16+metal*0.2)*exp(-t*decay)
            case 12,23,40:
                value=sin(t*(id==12 ? 1800:950)*2*Double.pi)*exp(-t*95)*0.75+noise*exp(-t*350)*0.1
            case 13,19,41:
                let bursts=exp(-t*95)+Double(t>=0.009)*exp(-max(0,t-0.009)*100)+Double(t>=0.018)*exp(-max(0,t-0.018)*80)
                value=high*0.18*bursts+noise*exp(-t*16)*0.08
            case 14,44,45:
                let metal=sin(t*3127*2*Double.pi)*sin(t*4871*2*Double.pi)
                value=(metal*0.25+high*0.08)*exp(-t*(id==45 ? 4:3))
            case 15...18,20,21,37...39:
                let frequency=90+Double(id%4)*45
                phase+=(frequency+frequency*0.2*exp(-t*30))/rate
                value=sin(phase*2*Double.pi)*exp(-t*(id>=37 ? 9:14))*0.8
            default:value=sin(t*220*2*Double.pi)*exp(-t*20)*0.25
            }
            let envelope=min(1,t*1000),sample=Int16(max(-32767,min(32767,Int(value*envelope*25000))))
            let bits=UInt16(bitPattern:sample);pcm.append(UInt8(bits>>8));pcm.append(UInt8(bits&255))
        }
        func be(_ number:Int,_ bytes:Int)->[UInt8]{(0..<bytes).map{UInt8((number>>((bytes-1-$0)*8))&255)}}
        var result=Array("FORM".utf8)+be(46+pcm.count,4)+Array("AIFFCOMM".utf8)+be(18,4)+be(1,2)+be(frames,4)+be(16,2)
        result += [0x40,0x0e,0xac,0x44,0,0,0,0,0,0]
        result += Array("SSND".utf8)+be(8+pcm.count,4)+be(0,4)+be(0,4)+pcm
        return Data(result)
    }
}
private extension Double {init(_ value:Bool){self=value ? 1:0}}
