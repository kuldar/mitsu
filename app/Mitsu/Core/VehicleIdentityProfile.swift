import Foundation

/// Local, ignored configuration. No owner's controller acceptance values ship.
struct VehicleIdentityProfile:Codable {
    let expectedBodyIdentity:[String:String]
    static let empty=VehicleIdentityProfile(expectedBodyIdentity:[:])
    static var bundled:Self {
        let url=Bundle.main.url(forResource:"VehicleIdentity.local",withExtension:"json")
        return decode(url.flatMap{try? Data(contentsOf:$0)})
    }
    static func decode(_ data:Data?)->Self {
        guard let data,let profile=try? JSONDecoder().decode(Self.self,from:data),
              Set(profile.expectedBodyIdentity.keys)==Set(["1A87","1A9C"]),
              profile.expectedBodyIdentity.allSatisfy({request,hex in
                  ((request=="1A87" ? 44:42)...256).contains(hex.count) && hex.count%2==0 && hex.hasPrefix("5A"+request.suffix(2)) &&
                  hex.allSatisfy{("0"..."9").contains(String($0)) || ("A"..."F").contains(String($0))}
              }) else{return .empty}
        return profile
    }
}
