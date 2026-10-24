import AuthenticationServices
import CryptoKit
import SwiftUI

struct SpotifyTrack: Decodable {
    struct Artist:Decodable { let name:String }
    struct Album:Decodable { struct Art:Decodable { let url:String }; let images:[Art] }
    let name:String
    let artists:[Artist]?
    let album:Album?
    let duration_ms:Int?
}
struct SpotifyPlayback:Decodable {
    struct Device:Decodable,Identifiable { let id:String?; let name:String; let is_active:Bool; let type:String? }
    let is_playing:Bool
    let progress_ms:Int?
    let item:SpotifyTrack?
    let device:Device?
}
private struct SpotifyToken:Codable { let access_token:String; let refresh_token:String; let expires:Date }

@MainActor final class SpotifyService:NSObject,ObservableObject,ASWebAuthenticationPresentationContextProviding {
    @Published var clientID=UserDefaults.standard.string(forKey:"spotify.clientID") ?? ""
    @Published private(set) var connected=false
    @Published private(set) var status="Connect Spotify"
    @Published private(set) var playback:SpotifyPlayback?
    @Published private(set) var devices:[SpotifyPlayback.Device]=[]
    @Published private(set) var busy=false
    private var token:SpotifyToken?
    private var auth:ASWebAuthenticationSession?
    private var refreshTask:Task<SpotifyToken,Error>?
    private var retryAt=Date.distantPast
    private var refreshing=false
    private var epoch=AuthorizationEpoch()
    private let redirect="com.example.mitsu://spotify-callback"
    override init() {
        super.init()
        if let d=KeychainStore.read("tokens"),let t=try? JSONDecoder().decode(SpotifyToken.self,from:d) { token=t; connected=true; status="Spotify connected"; _=epoch.begin() }
    }
    func presentationAnchor(for session:ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap(\.windows).first(where:{$0.isKeyWindow}) ?? ASPresentationAnchor()
    }
    func connect() {
        let id=clientID.trimmingCharacters(in:.whitespacesAndNewlines)
        guard id.count==32,id.allSatisfy({$0.isHexDigit}) else{status="Enter the Client ID from your Spotify developer app.";return}
        clientID=id; UserDefaults.standard.set(id,forKey:"spotify.clientID")
        auth?.cancel();refreshTask?.cancel();refreshTask=nil;refreshing=false;busy=false
        let session=epoch.begin()
        let verifier=(UUID().uuidString+UUID().uuidString).replacingOccurrences(of:"-",with:"")
        let state=UUID().uuidString
        let challenge=Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
        var url=URLComponents(string:"https://accounts.spotify.com/authorize")!
        url.queryItems=[.init(name:"client_id",value:id),.init(name:"response_type",value:"code"),.init(name:"redirect_uri",value:redirect),.init(name:"code_challenge_method",value:"S256"),.init(name:"code_challenge",value:challenge),.init(name:"state",value:state),.init(name:"scope",value:"user-read-playback-state user-read-currently-playing user-modify-playback-state")]
        status="Waiting for Spotify sign-in…"
        auth=ASWebAuthenticationSession(url:url.url!,callbackURLScheme:"com.example.mitsu") { [weak self] callback,error in
            Task { @MainActor in
                guard let self,self.epoch.isCurrent(session) else{return}
                guard let callback,error==nil else{self.status="Spotify sign-in cancelled";return}
                do {
                    let code=try OAuthCallback.validate(callback,state:state)
                    let value=try await self.exchange(["grant_type":"authorization_code","code":code,"redirect_uri":self.redirect,"client_id":id,"code_verifier":verifier])
                    guard self.epoch.isCurrent(session) else{return}
                    try self.save(value); await self.refresh()
                } catch { if self.epoch.isCurrent(session){self.status=error.localizedDescription} }
            }
        }
        auth?.presentationContextProvider=self; auth?.prefersEphemeralWebBrowserSession=false
        if auth?.start() != true { status="Could not open Spotify sign-in" }
    }
    func disconnect() {
        epoch.invalidate();refreshing=false;busy=false
        auth?.cancel(); auth=nil; refreshTask?.cancel(); refreshTask=nil
        token=nil; connected=false; playback=nil; devices=[]; status="Connect Spotify"
        do { try KeychainStore.write(nil,key:"tokens") } catch { status=error.localizedDescription }
    }
    private func save(_ value:SpotifyToken) throws { try KeychainStore.write(JSONEncoder().encode(value),key:"tokens"); token=value; connected=true }
    private func exchange(_ fields:[String:String],fallback:String?=nil) async throws -> SpotifyToken {
        var c=URLComponents(); c.queryItems=fields.sorted(by:{$0.key<$1.key}).map{URLQueryItem(name:$0.key,value:$0.value)}
        var r=URLRequest(url:URL(string:"https://accounts.spotify.com/api/token")!);r.httpMethod="POST";r.timeoutInterval=15
        r.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type");r.httpBody=c.percentEncodedQuery?.replacingOccurrences(of:"+",with:"%2B").data(using:.utf8)
        let (data,response)=try await URLSession.shared.data(for:r)
        guard (response as? HTTPURLResponse)?.statusCode==200 else{throw DiagnosticError.invalid("Spotify authorization failed. Check the Client ID and registered redirect URI.")}
        struct Reply:Decodable { let access_token:String;let refresh_token:String?;let expires_in:Double }
        let v=try JSONDecoder().decode(Reply.self,from:data)
        guard let refresh=v.refresh_token ?? fallback,!refresh.isEmpty else{throw DiagnosticError.invalid("Spotify did not return renewable authorization.")}
        return SpotifyToken(access_token:v.access_token,refresh_token:refresh,expires:Date().addingTimeInterval(v.expires_in))
    }
    private func access() async throws -> String {
        guard let token,let session=epoch.id else{throw DiagnosticError.invalid("Connect your Spotify account first.")}
        if token.expires.timeIntervalSinceNow>60{return token.access_token}
        if let refreshTask{let value=try await refreshTask.value;guard epoch.isCurrent(session) else{throw CancellationError()};return value.access_token}
        let clientID=self.clientID
        let task=Task { try await self.exchange(["grant_type":"refresh_token","refresh_token":token.refresh_token,"client_id":clientID],fallback:token.refresh_token) }
        refreshTask=task;defer{if epoch.isCurrent(session){refreshTask=nil}}
        let value=try await task.value;try Task.checkCancellation();guard connected,epoch.isCurrent(session) else{throw CancellationError()};try save(value);return value.access_token
    }
    private func api(_ path:String,method:String="GET",body:Data?=nil) async throws -> (Data,Int) {
        guard let session=epoch.id else{throw CancellationError()}
        guard Date()>=retryAt else{throw DiagnosticError.invalid("Spotify asked to wait. Controls will resume shortly.")}
        let access=try await access()
        guard epoch.isCurrent(session) else{throw CancellationError()}
        var r=URLRequest(url:URL(string:"https://api.spotify.com/v1/"+path)!);r.httpMethod=method;r.timeoutInterval=15;r.httpBody=body
        r.setValue("Bearer "+access,forHTTPHeaderField:"Authorization");r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let (data,response)=try await URLSession.shared.data(for:r)
        guard epoch.isCurrent(session) else{throw CancellationError()}
        guard let http=response as? HTTPURLResponse else{throw DiagnosticError.invalid("Spotify is unavailable")}
        switch PlaybackResponse.classify(status:http.statusCode,retryAfter:http.value(forHTTPHeaderField:"Retry-After")) {
        case .content,.empty:return (data,http.statusCode)
        case .unauthorized:throw DiagnosticError.invalid("Spotify authorization expired. Disconnect and connect again.")
        case .forbidden:throw DiagnosticError.invalid("Spotify denied this control. Check Premium and developer-app access.")
        case .retry(let seconds):retryAt=Date().addingTimeInterval(seconds);throw DiagnosticError.invalid("Spotify is busy. Retry in \(Int(seconds)) seconds.")
        case .failure:throw DiagnosticError.invalid(http.statusCode==404 ? "Open Spotify and start playback on your phone or iPad first." : "Spotify could not complete that request.")
        }
    }
    func refresh() async {
        guard connected,!refreshing,Date()>=retryAt,let session=epoch.id else{return};refreshing=true;defer{if epoch.isCurrent(session){refreshing=false}}
        do {
            let (data,code)=try await api("me/player")
            guard connected,epoch.isCurrent(session) else{return}
            if code==204 {playback=nil;status="Open Spotify on a playback device"}
            else {playback=try JSONDecoder().decode(SpotifyPlayback.self,from:data);status=playback?.device?.name ?? "Spotify connected"}
        } catch { if epoch.isCurrent(session){playback=nil;status="Spotify · "+error.localizedDescription} }
    }
    func control(_ action:String) {
        guard connected,!busy,["play","pause","next","previous"].contains(action),let session=epoch.id else{return}
        busy=true
        Task {
            defer{if epoch.isCurrent(session){busy=false}}
            do { _=try await api("me/player/"+action,method:["next","previous"].contains(action) ? "POST":"PUT");await refresh() }
            catch{if epoch.isCurrent(session){playback=nil;status=error.localizedDescription}}
        }
    }
    func loadDevices() async {
        guard let session=epoch.id else{return}
        do{let (data,_)=try await api("me/player/devices");guard epoch.isCurrent(session) else{return};struct List:Decodable{let devices:[SpotifyPlayback.Device]};devices=try JSONDecoder().decode(List.self,from:data).devices}catch{if epoch.isCurrent(session){status=error.localizedDescription}}
    }
    func transfer(to id:String) {
        guard !busy,let session=epoch.id else{return};busy=true
        Task { defer{if epoch.isCurrent(session){busy=false}};do{let data=try JSONSerialization.data(withJSONObject:["device_ids":[id],"play":false]);_=try await api("me/player",method:"PUT",body:data);await refresh()}catch{if epoch.isCurrent(session){playback=nil;status=error.localizedDescription}} }
    }
}
