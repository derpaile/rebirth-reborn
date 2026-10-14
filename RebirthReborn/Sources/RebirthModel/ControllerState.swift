import Foundation

extension Song {
    public var controllers:[[Int]] {
        var result=Array(repeating:Array(repeating:-1,count:32),count:9)
        func byte(_ v:Double)->Int{min(127,max(0,Int(v.rounded())))}
        let r=effectiveRack;result[0][1]=r.compressorTarget;result[0][2]=r.pcfTarget
        for d in 0..<4 {
            let p=6+6*d;result[0][p]=byte((d<2 ? bass[d].level:drums[d-2].level)*127)
            result[0][p+1]=byte(((d<2 ? bass[d].pan:drums[d-2].pan)+1)*63.5);result[0][p+2]=byte(r.sends[d]);result[0][p+3]=r.distorted[d] ? 1:0
        }
        for d in 0..<2 {
            result[d+1][0]=bass[d].enabled ? 1:0;result[d+1][1]=bass[d].selectedPattern
            for p in 0..<7{result[d+1][p+2]=p==6 ? (bass[d].controls[p]>0.5 ? 1:0):byte(bass[d].controls[p])}
            let c=drums[d].controls ?? DrumDefinitions.defaults(d)
            for p in c.indices{result[d+3][p]=byte(c[p])}
            result[d+3][0]=drums[d].enabled ? 1:0;result[d+3][1]=drums[d].selectedPattern
            for lane in 0..<11 {result[d+3][DrumDefinitions.levels[d][lane]]=byte(drums[d].voices[lane].level*127)}
        }
        for (d,c) in [(5,r.delay),(6,r.distortion),(7,r.pcf),(8,r.compressor)]{for p in c.indices{result[d][p]=byte(c[p])}}
        return result
    }
    public func controllerChanges(from prior:Song,at tick:Int)->[SongEvent] {
        let before=prior.controllers,after=controllers,time=min(100_000_000,max(0,((tick+12)/24)*24))
        var events=[SongEvent]()
        for d in 0..<9{for p in 0..<32 where after[d][p]>=0 && before[d][p] != after[d][p]{events.append(SongEvent(tick:time,device:d,parameter:p,value:after[d][p]))}}
        return events
    }
}

public struct MIDIMessage:Equatable {
    public var status:Int,first:Int=0,second:Int=0
    public init(status:Int,first:Int=0,second:Int=0){self.status=status;self.first=first;self.second=second}
}
public struct MIDIDecoder {
    private var status=0,bytes=[Int](),sysex=false
    public init(){}
    public mutating func feed(_ input:[UInt8])->[MIDIMessage] {
        var messages=[MIDIMessage]()
        for byte in input {
            let b=Int(byte)
            if b>=0xf8{messages.append(MIDIMessage(status:b));continue}
            if b>=0x80 {
                bytes=[]
                if b==0xf0{sysex=true;status=0;continue}
                if b==0xf7{sysex=false;status=0;continue}
                if b>=0xf0{status=[0xf1,0xf2,0xf3].contains(b) ? b:0;continue}
                sysex=false;status=b;continue
            }
            guard !sysex,status>=0x80 else{continue}
            bytes.append(b);let count=[0xc0,0xd0].contains(status&0xf0) || [0xf1,0xf3].contains(status) ? 1:2
            if bytes.count==count{messages.append(MIDIMessage(status:status,first:bytes[0],second:count==2 ? bytes[1]:0));bytes=[];if status>=0xf0{status=0}}
        }
        return messages
    }
}
