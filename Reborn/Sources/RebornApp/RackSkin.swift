import SwiftUI
import AppKit
import RebornModel

final class RackSkin {
    let name:String
    private var images=[Int:NSImage](),plates=[Int:NSImage](),crops=[String:NSImage]()
    init?(mod:RebornSoundPack){
        name=mod.name
        for (file,data) in mod.files where ["jpg","png"].contains(file.split(separator:".").last.map{String($0).lowercased()} ?? ""){
            guard let id=Int(file.split(separator:".")[0]),let image=NSImage(data:data),let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),cg.width<=4096,cg.height<=4096 else{continue}
            images[id]=image
        }
        guard images[12500] != nil || images[12520] != nil else{return nil}
    }
    func image(_ id:Int)->NSImage?{images[id]}
    func plate(_ id:Int)->NSImage?{
        if let cached=plates[id]{return cached}
        guard let image=images[id],let standard=RackDrawing.plate(id),let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil) else{return nil}
        let plate=NSImage(cgImage:cg,size:standard.size);plates[id]=plate;return plate
    }
    func sprite(_ id:Int,index:Int,width:CGFloat,height:CGFloat,stride:CGFloat)->NSImage?{
        let key="\(id):\(index):\(width):\(height):\(stride)"
        if let cached=crops[key]{return cached}
        guard let source=images[id]?.cgImage(forProposedRect:nil,context:nil,hints:nil),CGFloat(index)*stride+width<=CGFloat(source.width),height<=CGFloat(source.height),let crop=source.cropping(to:CGRect(x:CGFloat(index)*stride,y:0,width:width,height:height)) else{return nil}
        let image=NSImage(cgImage:crop,size:NSSize(width:width,height:height));crops[key]=image;return image
    }
}
private struct RackSkinKey:EnvironmentKey {static let defaultValue:RackSkin?=nil}
extension EnvironmentValues {var rackSkin:RackSkin?{get{self[RackSkinKey.self]}set{self[RackSkinKey.self]=newValue}}}
