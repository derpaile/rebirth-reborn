import SwiftUI
import AppKit

struct RackControlInput:NSViewRepresentable {
    @Binding var value:Double
    var range:ClosedRange<Double>
    var reset:Double
    var relative=true
    var editing:(Bool)->Void
    func makeNSView(context:Context)->RackControlMouseView{let view=RackControlMouseView();update(view);return view}
    func updateNSView(_ view:RackControlMouseView,context:Context){update(view)}
    private func update(_ view:RackControlMouseView){view.value=$value;view.range=range;view.reset=reset;view.relative=relative;view.editing=editing}
}
final class RackControlMouseView:NSView {
    var value:Binding<Double> = .constant(0)
    var range:ClosedRange<Double> = 0...127
    var reset=64.0,relative=true
    var editing:(Bool)->Void = {_ in}
    private var previousY:CGFloat=0
    private var dragValue=0.0
    override var acceptsFirstResponder:Bool{true}
    override func isAccessibilityElement()->Bool{false}
    override func resetCursorRects(){addCursorRect(bounds,cursor:.resizeUpDown)}
    private func set(_ new:Double){let clamped=min(range.upperBound,max(range.lowerBound,new));if abs(clamped-value.wrappedValue)>0.00001{value.wrappedValue=clamped}}
    override func mouseDown(with event:NSEvent){
        window?.makeFirstResponder(self)
        if event.clickCount==2{set(reset);editing(false);return}
        previousY=convert(event.locationInWindow,from:nil).y;dragValue=value.wrappedValue;editing(true)
        if !relative && !event.modifierFlags.contains(.shift){setAbsolute(previousY);dragValue=value.wrappedValue}
    }
    override func mouseDragged(with event:NSEvent){
        let y=convert(event.locationInWindow,from:nil).y
        if relative || event.modifierFlags.contains(.shift){
            let sensitivity=(range.upperBound-range.lowerBound)/(relative ? 140:max(1,Double(bounds.height)))
            dragValue=min(range.upperBound,max(range.lowerBound,dragValue+Double(y-previousY)*sensitivity*(event.modifierFlags.contains(.shift) ? 0.1:1)))
            set(dragValue)
        }else{setAbsolute(y);dragValue=value.wrappedValue}
        previousY=y
    }
    private func setAbsolute(_ y:CGFloat){set(range.lowerBound+min(1,max(0,Double(y/max(1,bounds.height))))*(range.upperBound-range.lowerBound))}
    override func mouseUp(with event:NSEvent){editing(false)}
    override func scrollWheel(with event:NSEvent){
        let delta=Double(event.scrollingDeltaY)*(event.hasPreciseScrollingDeltas ? 0.1:1)
        set(value.wrappedValue+delta*(range.upperBound-range.lowerBound)/127*(event.modifierFlags.contains(.shift) ? 0.1:1))
    }
    override func keyDown(with event:NSEvent){
        if [123,124,125,126].contains(event.keyCode){let direction=event.keyCode==124 || event.keyCode==126 ? 1.0:-1.0;set(value.wrappedValue+direction*(range.upperBound-range.lowerBound)/127*(event.modifierFlags.contains(.shift) ? 0.1:1))}
        else if event.keyCode==53{editing(false);window?.makeFirstResponder(nil)}
        else{super.keyDown(with:event)}
    }
}

struct EditableRackNumber:View {
    @Binding var value:Double
    var digits=2
    var range:ClosedRange<Double>
    var title:String
    @State private var open=false
    @State private var draft=""
    @State private var invalid=false
    @FocusState private var focused:Bool
    private func commit(){
        guard let number=Double(draft.replacingOccurrences(of:",",with:".")),number.isFinite,range.contains(number) else{invalid=true;return}
        value=number.rounded();open=false
    }
    var body:some View {
        OriginalNumber(value:Int(value.rounded()),digits:digits)
            .contentShape(Rectangle()).onTapGesture(count:2){draft=String(Int(value.rounded()));invalid=false;open=true}
            .accessibilityAction(named:"Wert eingeben"){draft=String(Int(value.rounded()));invalid=false;open=true}
            .help("\(title): Doppelklick zur Eingabe")
            .popover(isPresented:$open){
                VStack(alignment:.leading,spacing:8){
                    Text(title).font(.headline)
                    TextField("\(Int(range.lowerBound))–\(Int(range.upperBound))",text:$draft).textFieldStyle(.roundedBorder).focused($focused).onSubmit(commit)
                    if invalid{Text("Zahl von \(Int(range.lowerBound)) bis \(Int(range.upperBound)) eingeben.").font(.caption).foregroundStyle(.red)}
                    HStack{Button("Abbrechen"){open=false}.keyboardShortcut(.cancelAction);Spacer();Button("Übernehmen",action:commit).keyboardShortcut(.defaultAction)}
                }.padding(12).frame(width:210).onAppear{focused=true}
            }
    }
}
