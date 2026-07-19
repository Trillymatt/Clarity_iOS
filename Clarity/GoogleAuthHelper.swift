import Foundation
import AuthenticationServices

class GoogleAuthHelper: NSObject {
    static let clientID = "299944978186-en4k9thjnnomdc750uhmho54ath2ei17.apps.googleusercontent.com"
    
    // Derived properties
    static var urlScheme: String {
        return clientID.components(separatedBy: ".").reversed().joined(separator: ".")
    }
    
    static var redirectURI: String {
        return "\(urlScheme):/oauth2redirect/google"
    }
    
    static func getAuthURL() -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "email profile openid")
        ]
        return components?.url
    }
    
    static func handleCallback(url: URL, completion: @escaping (String?, String?) -> Void) {
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            completion(nil, nil)
            return
        }
        
        exchangeCodeForToken(code: code, completion: completion)
    }
    
    private static func exchangeCodeForToken(code: String, completion: @escaping (String?, String?) -> Void) {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": clientID,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                completion(nil, nil)
                return
            }
            
            fetchUserInfo(token: accessToken, completion: completion)
        }.resume()
    }
    
    private static func fetchUserInfo(token: String, completion: @escaping (String?, String?) -> Void) {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else {
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil, nil)
                return
            }
            
            let name = json["name"] as? String
            let email = json["email"] as? String
            completion(name, email)
        }.resume()
    }
}
