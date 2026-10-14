import Foundation
import RebirthDSP

public struct EffectSettings: Codable, Equatable {
    public init() {}
    public var distortion = [1.0,70,0]
    public var delay = [1.0,3,1,80,64]
    public var compressor = [1.0,70,64]
    public var pcf = [1.0,70,64,40,24,90,1]
    public var sends = [0.0,0,0,0]
    public var distorted = [false,false,false,false]
    public var pcfTarget = 0
    public var compressorTarget = 0
    public var valid: Bool {
        let arrays = [distortion,delay,compressor,pcf,sends]
        return arrays.map(\.count)==[3,5,3,7,4] && arrays.flatMap{$0}.allSatisfy{$0.isFinite && (0...127).contains($0)} && distorted.count==4 && (0...4).contains(pcfTarget) && (0...5).contains(compressorTarget) && [distortion[0],delay[0],compressor[0],pcf[0],delay[2],pcf[6]].allSatisfy{[0.0,1.0].contains($0)} && (0...54).contains(pcf[4])
    }
    public static func legacy(_ values: [Double]) -> EffectSettings {
        var result=EffectSettings()
        result.distortion[1]=(values[0]*127).rounded()
        result.distorted=Array(repeating:values[0]>0,count:4)
        result.sends=Array(repeating:(values[1]*127).rounded(),count:4)
        result.delay[3]=(values[2]*127).rounded()
        result.compressor[1]=(values[3]*127).rounded()
        result.compressorTarget=values[3]>0 ? 1 : 0
        result.pcf[3]=(values[4]*127).rounded()
        result.pcfTarget=values[4]>0 ? 1 : 0
        return result
    }
    @discardableResult public func apply(to engine: OpaquePointer) -> Bool {
        guard valid else{return false}
        var accepted=true
        for (effect,controls) in [distortion,delay,compressor,pcf].enumerated() {
            for (id,value) in controls.enumerated() {if rb_effect_parameter(engine,Int32(effect),Int32(id),Int32(value.rounded()))==0 {accepted=false}}
        }
        for device in 0..<4 {if rb_channel_effects(engine,Int32(device),Int32(sends[device].rounded()),distorted[device] ? 1 : 0)==0 {accepted=false}}
        if rb_effect_routes(engine,Int32(pcfTarget),Int32(compressorTarget))==0 {accepted=false}
        return accepted
    }
}
