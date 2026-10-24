import Foundation

/// Rejects callbacks outside the current connection phase, including same-device reconnects.
struct BLELifecycle {
    enum Phase:Equatable {case idle,connecting(UUID),services(UUID),characteristics(UUID),notifications(UUID),ready(UUID),disconnecting(UUID)}
    private(set) var phase:Phase = .idle
    mutating func begin(_ id:UUID)->Bool{guard phase == .idle else{return false};phase = .connecting(id);return true}
    mutating func connected(_ id:UUID)->Bool{guard phase == .connecting(id) else{return false};phase = .services(id);return true}
    mutating func services(_ id:UUID)->Bool{guard phase == .services(id) else{return false};phase = .characteristics(id);return true}
    mutating func characteristics(_ id:UUID)->Bool{guard phase == .characteristics(id) else{return false};phase = .notifications(id);return true}
    mutating func notifications(_ id:UUID)->Bool{guard phase == .notifications(id) else{return false};phase = .ready(id);return true}
    mutating func disconnect(_ id:UUID){phase = .disconnecting(id)}
    mutating func disconnected(_ id:UUID)->Bool{
        switch phase{
        case .connecting(let current),.services(let current),.characteristics(let current),.notifications(let current),.ready(let current),.disconnecting(let current):
            guard current == id else{return false};phase = .idle;return true
        case .idle:return false
        }
    }
    var idle:Bool{phase == .idle}
}
