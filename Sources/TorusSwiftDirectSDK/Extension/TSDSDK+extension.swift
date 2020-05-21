//
//  TorusSwiftDirectSDK class
//  TorusSwiftDirectSDK
//
//  Created by Shubham Rathi on 18/05/2020.
//

import Foundation
import UIKit
import TorusUtils
import PromiseKit

@available(iOS 11.0, *)
extension TorusSwiftDirectSDK{
    
    open class var notificationCenter: NotificationCenter {
        return NotificationCenter.default
    }
    open class var notificationQueue: OperationQueue {
        return OperationQueue.main
    }
    
    static let didHandleCallbackURL: Notification.Name = .init("TSDSDKCallbackNotification")
    
    /// Remove internal observer on authentification
    public func removeCallbackNotificationObserver() {
        if let observer = self.observer {
            TorusSwiftDirectSDK.notificationCenter.removeObserver(observer)
        }
    }
    
    func observeCallback(_ block: @escaping (_ url: URL) -> Void) {
        self.observer = TorusSwiftDirectSDK.notificationCenter.addObserver(
            forName: TorusSwiftDirectSDK.didHandleCallbackURL,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
                self?.removeCallbackNotificationObserver()
                // print(notification.userInfo)
                if let urlFromUserInfo = notification.userInfo?["URL"] as? URL {
                    // print("calling block")
                    block(urlFromUserInfo)
                }else{
                    assertionFailure()
                }
        }
    }
    
    public func openURL(url: String) {
        // print("opening URL \(url)")
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(URL(string: url)!)
        } else {
            UIApplication.shared.openURL(URL(string: url)!)
        }
    }
    
    func makeUrlRequest(url: String, method: String) -> URLRequest {
        var rq = URLRequest(url: URL(string: url)!)
        rq.httpMethod = method
        rq.addValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.addValue("application/json", forHTTPHeaderField: "Accept")
        return rq
    }
    
    //    func getUserInfo(accessToken : String, subv: SubVerifierDetails) -> Promise<[String: Any]>{
    //
    //
    //        switch subv.typeOfLogin{
    //        case .auth0:
    //            break
    //        case .google:
    //            request = makeUrlRequest(url: "https://www.googleapis.com/userinfo/v2/me", method: "GET")
    //            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    //
    //            break
    //        case .discord:
    //            request = makeUrlRequest(url: "https://discordapp.com/api/users/@me", method: "GET")
    //            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    //
    //            break
    //        case .facebook:
    //            break
    //        case .twitch:
    //            break
    //        case .reddit:
    //            break
    //        }
    //
    //        return Promise<[String:Any]>{ seal in
    //            URLSession.shared.dataTask(with: request) { data, response, error in
    //                if error != nil || data == nil {
    //                    print("Client error!")
    //                    return
    //                }
    //                // print(response)
    //                do {
    //                    let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]
    //                    print(json)
    //                    seal.fulfill(json)
    //                } catch {
    //                    print("JSON error: \(error.localizedDescription)")
    //                }
    //
    //            }.resume()
    //        }
    //    }
    //
    open class func handle(url: URL){
        let notification = Notification(name: TorusSwiftDirectSDK.didHandleCallbackURL, object: nil, userInfo: ["URL":url])
        notificationCenter.post(notification)
    }
}

enum verifierTypes : String{
    case singleLogin = "single_login"
    case singleIdVerifier = "single_id_verifier"
    case andAggregateVerifier =  "and_aggregate_verifier"
    case orAggregateVerifier = "or_aggregate_verifier"
}

enum LoginProviders : String {
    case google = "google"
    case facebook = "facebook"
    case twitch = "twitch"
    case reddit = "reddit"
    case discord = "discord"
    case auth0 = "auth0"
    
    func getLoginURL(clientId: String) -> String{
        switch self{
        case .google:
            return "https://accounts.google.com/o/oauth2/v2/auth?response_type=token+id_token&client_id=\(clientId)&nonce=123&redirect_uri=https://backend.relayer.dev.tor.us/redirect&scope=profile+email+openid"
            break
        case .facebook:
            break
        case .twitch:
            break
        case .reddit:
            break
        case .discord:
            return "https://discord.com/api/oauth2/authorize?response_type=token" + "&client_id=\(clientId)&scope=email identify&redirect_uri=tdsdk://tdsdk/oauthCallback".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            break
        case .auth0:
            break
        }
        return "false"
    }
    
    func makeUrlRequest(url: String, method: String) -> URLRequest {
        var rq = URLRequest(url: URL(string: url)!)
        rq.httpMethod = method
        rq.addValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.addValue("application/json", forHTTPHeaderField: "Accept")
        return rq
    }
    
    func getUserInfo(responseParameters: [String:String]) -> Promise<[String:Any]>{
        
        // Modify to fit closure value init
        var request: URLRequest = makeUrlRequest(url: "https://www.googleapis.com/oauth2/v3/userinfo", method: "GET")
        var tokenForKeys = ""
        
        switch self{
        case .google:
            if let accessToken = responseParameters["access_token"], let idToken = responseParameters["id_token"]{
                request = makeUrlRequest(url: "https://www.googleapis.com/userinfo/v2/me", method: "GET")
                request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                tokenForKeys = idToken
            }
            break
        case .facebook:
            break
        case .twitch:
            break
        case .reddit:
            break
        case .discord:
            if let accessToken = responseParameters["access_token"] {
                request = makeUrlRequest(url: "https://discordapp.com/api/users/@me", method: "GET")
                request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                tokenForKeys = accessToken
            }
            break
        case .auth0:
            break
        }
        
        return Promise<[String:Any]>{ seal in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil || data == nil {
                    print("Client error!")
                    return
                }
                // print(response)
                do {
                    var json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]
                    json["tokenForKeys"] = tokenForKeys
                    json["verifierId"] = self.getUserInfoVerifier(data: json)
                    print(json)
                    seal.fulfill(json)
                } catch {
                    print("JSON error: \(error.localizedDescription)")
                }
                
            }.resume()
        }
    }
    
    func getUserInfoVerifier(data: [String: Any]) -> String{
        switch self{
        case .google:
            return data["email"] as! String
        case .facebook:
            break
        case .twitch:
            break
        case .reddit:
            break
        case .discord:
            return data["id"] as! String
        case .auth0:
            break
        }
        return "false"
    }
}

struct SubVerifierDetails {
    let clientId: String
    let typeOfLogin: LoginProviders
    let subVerifierId: String
    
    enum codingKeys: String, CodingKey{
        case clientId
        case typeOfLogin
        case subVerifierId
    }
    
    init(dictionary: [String: String]) throws {
        self.clientId = dictionary["clientId"] ?? ""
        self.typeOfLogin = LoginProviders(rawValue: dictionary["typeOfLogin"] ?? "")!
        self.subVerifierId = dictionary["verifier"] ?? ""
    }
}

