import Foundation

public enum DrumDefinitions {
    public static let levels = [[3,6,9,12,15,18,20,22,23,26,28],[3,7,11,14,17,20,21,22,22,25,27]]
    public static let parameters = [
        [ [(4,"TONE"),(5,"DECAY")],[(7,"TONE"),(8,"SNAPPY")],[(10,"TUNE"),(11,"TOM")],[(13,"TUNE"),(14,"TOM")],[(16,"TUNE"),(17,"TOM")],[(19,"RIM")],[(21,"CLAP")],[],[(24,"TONE"),(25,"DECAY")],[(27,"DECAY")],[] ],
        [ [(4,"TUNE"),(5,"ATTACK"),(6,"DECAY")],[(8,"TUNE"),(9,"TONE"),(10,"SNAPPY")],[(12,"TUNE"),(13,"DECAY")],[(15,"TUNE"),(16,"DECAY")],[(18,"TUNE"),(19,"DECAY")],[],[],[(23,"DECAY")],[(24,"DECAY")],[(26,"TUNE")],[(28,"TUNE")] ]
    ]
    public static func defaults(_ device: Int) -> [Double] {
        device == 0 ? [1,0,40,100,64,64,100,64,64,100,64,0,100,64,0,100,64,0,100,0,100,0,100,100,0,100,100,100,100] : [1,0,32,100,64,64,127,100,64,64,64,100,64,127,100,64,127,100,64,127,100,100,100,32,127,100,64,100,64,64]
    }
    public static func isSwitch(_ device: Int,_ parameter: Int) -> Bool { device == 0 && [11,14,17,19,21].contains(parameter) }
}
