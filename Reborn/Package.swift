// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"Reborn",platforms:[.macOS(.v13)],products:[
    .executable(name:"Reborn",targets:["RebornApp"]),
    .executable(name:"RebornCheck",targets:["RebornCheck"]),
    .executable(name:"RebornEffectsCheck",targets:["RebornEffectsCheck"])
],targets:[
    .target(name:"RebornDSP",publicHeadersPath:"include",cxxSettings:[.unsafeFlags(["-fno-strict-aliasing"])]),
    .target(name:"RebornModel",dependencies:["RebornDSP"]),
    .executableTarget(name:"RebornApp",dependencies:["RebornDSP","RebornModel"]),
    .executableTarget(name:"RebornCheck",dependencies:["RebornDSP","RebornModel"]),
    .executableTarget(name:"RebornEffectsCheck")
],cxxLanguageStandard:.cxx17)
