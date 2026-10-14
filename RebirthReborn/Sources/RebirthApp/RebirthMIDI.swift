import Foundation
import CoreMIDI
import Darwin
import RebirthModel

struct MIDIInputEvent {var message:MIDIMessage,source:Int32,seconds:Double}
struct MIDISource:Identifiable {let id:Int32,name:String}
final class RebirthMIDI {
    private var client=MIDIClientRef(),port=MIDIPortRef(),sources=[MIDIEndpointRef]()
    private var decoders=[UInt:MIDIDecoder]()
    private let lock=NSLock(),receive:([MIDIInputEvent])->Void
    static var availableSources:[MIDISource]{(0..<MIDIGetNumberOfSources()).map{index in let source=MIDIGetSource(index);var id:Int32=0;MIDIObjectGetIntegerProperty(source,kMIDIPropertyUniqueID,&id);var label:Unmanaged<CFString>?;MIDIObjectGetStringProperty(source,kMIDIPropertyDisplayName,&label);return MIDISource(id:id,name:label?.takeRetainedValue() as String? ?? "MIDI \(index+1)")}}
    init(receive:@escaping ([MIDIInputEvent])->Void)throws{
        self.receive=receive
        let status=MIDIClientCreateWithBlock("Rebirth Reborn" as CFString,&client){[weak self] _ in DispatchQueue.main.async{self?.connectSources()}}
        guard status==noErr else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(status))}
        let input=MIDIInputPortCreateWithBlock(client,"Input" as CFString,&port){[weak self] list,source in
            guard let self else{return}
            let sourceID=UInt(bitPattern:source);var uid:Int32=0;MIDIObjectGetIntegerProperty(MIDIObjectRef(sourceID),kMIDIPropertyUniqueID,&uid)
            var timebase=mach_timebase_info_data_t();mach_timebase_info(&timebase)
            var packet=UnsafeRawPointer(list).advanced(by:MemoryLayout<MIDIPacketList>.offset(of:\.packet)!).assumingMemoryBound(to:MIDIPacket.self)
            var messages=[MIDIInputEvent]()
            self.lock.lock();var decoder=self.decoders[sourceID] ?? MIDIDecoder()
            for _ in 0..<list.pointee.numPackets{
                let start=UnsafeRawPointer(packet).advanced(by:MemoryLayout<MIDIPacket>.offset(of:\.data)!).assumingMemoryBound(to:UInt8.self)
                let host=packet.pointee.timeStamp==0 ? mach_absolute_time():packet.pointee.timeStamp
                let seconds=Double(host)*Double(timebase.numer)/Double(timebase.denom)/1e9
                messages+=decoder.feed(Array(UnsafeBufferPointer(start:start,count:Int(packet.pointee.length)))).map{MIDIInputEvent(message:$0,source:uid,seconds:seconds)}
                packet=UnsafePointer(MIDIPacketNext(packet))
            }
            self.decoders[sourceID]=decoder;self.lock.unlock()
            if !messages.isEmpty{DispatchQueue.main.async{self.receive(messages)}}
        }
        guard input==noErr else{MIDIClientDispose(client);client=0;throw NSError(domain:NSOSStatusErrorDomain,code:Int(input))};connectSources()
    }
    private func connectSources(){guard port != 0 else{return};for source in sources{MIDIPortDisconnectSource(port,source)};sources=[];lock.lock();decoders=[:];lock.unlock();for i in 0..<MIDIGetNumberOfSources(){let source=MIDIGetSource(i);if MIDIPortConnectSource(port,source,UnsafeMutableRawPointer(bitPattern:Int(source)))==noErr{sources.append(source)}}}
    deinit{if port != 0{MIDIPortDispose(port)};if client != 0{MIDIClientDispose(client)}}
}
