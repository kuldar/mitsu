import Foundation
import Security

enum KeychainStore {
    static func read(_ key:String) -> Data? {
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.example.mitsu.spotify",kSecAttrAccount as String:key,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess else{return nil}; return result as? Data
    }
    static func write(_ data:Data?,key:String) throws {
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.example.mitsu.spotify",kSecAttrAccount as String:key]
        SecItemDelete(q as CFDictionary)
        guard let data else{return}
        var insert=q; insert[kSecValueData as String]=data; insert[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary,nil)==errSecSuccess else{throw DiagnosticError.invalid("Spotify authorization could not be saved securely.")}
    }
}
