import Foundation

struct AuthorizationEpoch {
    private var current:UUID?
    mutating func begin()->UUID{let id=UUID();current=id;return id}
    mutating func invalidate(){current=nil}
    func isCurrent(_ id:UUID)->Bool{current == id}
    var id:UUID?{current}
}

enum WeatherFreshness: Equatable {
    case current, cached, expired
    static func evaluate(age: TimeInterval, sameArea: Bool) -> Self {
        guard sameArea, age.isFinite, age >= 0, age <= 10_800 else { return .expired }
        return age <= 1800 ? .current : .cached
    }
}

enum OAuthCallback {
    static func validate(_ url: URL, state: String) throws -> String {
        guard url.scheme == "com.example.mitsu", url.host == "spotify-callback",
              let items = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems,
              items.filter({$0.name == "state"}).count == 1,
              items.first(where:{$0.name == "state"})?.value == state,
              !state.isEmpty, items.first(where:{$0.name == "error"}) == nil,
              items.filter({$0.name == "code"}).count == 1,
              let code = items.first(where:{$0.name == "code"})?.value, !code.isEmpty else { throw DiagnosticError.invalid("Spotify sign-in could not be verified. Try connecting again.") }
        return code
    }
}

enum PlaybackResponse: Equatable {
    case content, empty, unauthorized, forbidden, retry(after: TimeInterval), failure
    static func classify(status: Int, retryAfter: String?) -> Self {
        switch status {
        case 200...203: return .content
        case 204: return .empty
        case 401: return .unauthorized
        case 403: return .forbidden
        case 429: return .retry(after:max(1,Double(retryAfter ?? "") ?? 30))
        default: return .failure
        }
    }
}
