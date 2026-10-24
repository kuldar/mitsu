import Foundation

/// Invented controller part bytes. These are test data, never a vehicle profile.
enum DiagnosticFixtures {
    static let identity87="504 10 16 5A 87 04 82 00 00\r504 21 FF 36 01 4D 03 00 30\r504 22 30 30 30 30 30 30 30\r504 23 20 20 00 00 00 00 00"
    static let identity9C="504 10 15 5A 9C 01 04 82 00\r504 21 00 FF 4D 03 00 30 30\r504 22 30 30 30 30 30 30 2D\r504 23 58 20 00 00 00 00 00"
    static var expectedIdentity:[String:String] {
        Dictionary(uniqueKeysWithValues:zip(["1A87","1A9C"],[identity87,identity9C]).map{request,raw in
            (request,try! OBDCodec.frames(raw)[0].payload.map{String(format:"%02X",$0)}.joined())
        })
    }
}
