import Foundation
import RebirthDSP

// Prepare every sample before changing the live bank. Commit only with rendering stopped.
public final class RebirthSampleBank {
    private let bank:OpaquePointer
    public init(_ samples:[Data])throws {
        guard samples.count==46,let b=rb_sample_bank_create() else{throw RebornSoundPack.ReadError.invalid("46 Samples benötigt.")}
        for (i,data) in samples.enumerated() {
            guard data.count<=32*1024*1024,data.withUnsafeBytes({rb_sample_bank_aiff(b,Int32(i),$0.bindMemory(to:UInt8.self).baseAddress,UInt32(data.count))})==1 else {
                rb_sample_bank_destroy(b);throw RebornSoundPack.ReadError.invalid("Sample \(RebornSoundPack.sampleNames[i]) ist beschädigt oder nicht unterstützt.")
            }
        }
        bank=b
    }
    deinit {rb_sample_bank_destroy(bank)}
    public func commit(to engine:OpaquePointer)throws {
        guard rb_sample_bank_commit(engine,bank)==1 else{throw RebornSoundPack.ReadError.invalid("Samplewechsel benötigt eine gestoppte Wiedergabe.")}
    }
}
