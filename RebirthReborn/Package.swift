// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"RebirthReborn",platforms:[.macOS(.v13)],products:[
    .executable(name:"Rebirth",targets:["RebirthApp"]),
    .executable(name:"RebirthCheck",targets:["RebirthCheck"]),
    .executable(name:"RebirthEffectsCheck",targets:["RebirthEffectsCheck"])
],targets:[
    .target(name:"RebirthDSP",publicHeadersPath:"include",cxxSettings:[.unsafeFlags(["-fno-strict-aliasing"])]),
    .target(name:"RebirthModel",dependencies:["RebirthDSP"]),
    .executableTarget(name:"RebirthApp",dependencies:["RebirthDSP","RebirthModel"]),
    .executableTarget(name:"RebirthCheck",dependencies:["RebirthDSP","RebirthModel"]),
    .executableTarget(name:"RebirthEffectsCheck")
],cxxLanguageStandard:.cxx17)
