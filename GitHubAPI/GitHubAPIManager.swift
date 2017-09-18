//
//  GitHubAPIManager.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation
import Alamofire
import Locksmith

class GitHubAPIManager: NSObject {
    
    static let shared = GitHubAPIManager()
    
    var OAuthTokenCompletionHandler:((Error?) -> Void)?
    
    var isLoadingOAuthToken: Bool = false
    var OAuthToken: String? {
        set {
            guard let newValue = newValue else {
                let _ = try? Locksmith.deleteDataForUserAccount(userAccount: "github")
                return
            }
            
            guard let _ = try? Locksmith.updateData(data: ["token": newValue], forUserAccount: "github") else {
                let _ = try? Locksmith.deleteDataForUserAccount(userAccount: "github")
                return
            }
        }
        get {
            let dictionary = Locksmith.loadDataForUserAccount(userAccount: "github")
            return dictionary?["token"] as? String
        }
    }
    
    let clientID: String = "573329981c488a0f27b2"
    let clientSecret: String = "eb078e70f025b6598f31b51c13b550a6b1502f2d"
    
    func clearCache() {
        let cache = URLCache.shared
        cache.removeAllCachedResponses()
    }
    
    func hasOAuthToken() -> Bool {
        if let token = self.OAuthToken {
            return !token.isEmpty
        }
        return false
    }
    
    func processOAuthStep1Response(_ url: URL) {
        guard let code = extractCodeFromOAuthStep1Response(url) else {
            self.isLoadingOAuthToken = false
            let error = GitHubAPIManagerError.authCouldNot(reason:
                "Could not obtain an OAuth token")
            self.OAuthTokenCompletionHandler?(error)
            return
        }
        
        swapAuthCodeForToken(code: code)
        
    }
    
    func swapAuthCodeForToken(code: String) {
        let getTokenPath: String = "https://github.com/login/oauth/access_token"
        let tokenParams = ["client_id": clientID, "client_secret": clientSecret, "code": code]
        
        let jsonHeader = ["Accept": "application/json"]
        Alamofire.request(getTokenPath, method: .post, parameters: tokenParams,
                          encoding: URLEncoding.default, headers: jsonHeader)
            .responseJSON { response in
                guard response.result.error == nil else {
                    print(response.result.error!)
                    self.isLoadingOAuthToken = false
                    let errorMesage = response.result.error?.localizedDescription ??
                    "Could not obtain an OAuth token"
                    let error = GitHubAPIManagerError.authCouldNot(reason: errorMesage)
                    self.OAuthTokenCompletionHandler?(error)
                    return
                }
                guard let value = response.result.value else {
                    print("No string received in response when swapping oauth code for token")
                    self.isLoadingOAuthToken = false
                    let error = GitHubAPIManagerError.authCouldNot(reason:
                        "Could not obtain an OAuth token")
                    self.OAuthTokenCompletionHandler?(error)
                    return
                }
                guard let jsonResult = value as? [String: String] else {
                    print("no data received or data not JSON")
                    self.isLoadingOAuthToken = false
                    let error = GitHubAPIManagerError.authCouldNot(reason:
                        "Could not obtain an OAuth token")
                    self.OAuthTokenCompletionHandler?(error)
                    return
                }
                self.OAuthToken = self.parseOAuthTokenResponse(jsonResult)
                
                self.isLoadingOAuthToken = false
                if (self.hasOAuthToken()) {
                    self.OAuthTokenCompletionHandler?(nil)
                } else {
                    let error = GitHubAPIManagerError.authCouldNot(reason:
                        "Could not obtain an OAuth token")
                    self.OAuthTokenCompletionHandler?(error)
                }
        }
    }
    
    func checkUnauthorized(urlResponse: HTTPURLResponse) -> (Error?) {
        if (urlResponse.statusCode == 401) {
            self.OAuthToken = nil
            return GitHubAPIManagerError.authLost(reason: "Not Logged In")
        }
        return nil
    }
    
    func parseOAuthTokenResponse(_ json: [String: String]) -> String? {
        var token: String?
        for (key, valuue) in json {
            switch key {
            case "access_token":
                token = valuue
            case "scope":
                print("SET SCOPE")
            case "token_type":
                print("CHECK IF BEARER")
            default:
                print("Got more than I expected from the OAuth token exchange")
                print(key)
            }
        }
        return token
    }
    
    func extractCodeFromOAuthStep1Response(_ url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var code: String?
        guard let quertyItems = components?.queryItems else {
            return nil
        }
        for quertyItem in quertyItems {
            if (quertyItem.name.lowercased() == "code") {
                code = quertyItem.value
                break
            }
        }
        return code
    }
    
    func URLToStartOAuth2Login() -> URL? {
        let authPath: String = "https://github.com/login/oauth/authorize" +
        "?client_id=\(clientID)&scope=gist&state=TEST_STATE"
        return URL(string: authPath)
    }
    
    func printMyStarredGistsWithOAuth2() -> Void {
        Alamofire.request(GistRouter.getMyStarred())
        .responseString { response in
            guard let receivedString = response.result.value else {
                print("Error: didn't get a string in the response")
                return
            }
            print(receivedString)
        }
    }
    
    func isGistStarred(_ gistId: String, completionHandler:
        @escaping (Result<Bool>) -> Void) {
        Alamofire.request(GistRouter.isStarred(gistId))
            .validate(statusCode: [204])
            .response { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(.failure(authError))
                    return
                }
                
                //204 if starred, 404 if not
                if let error = response.error {
                    print(error)
                    if response.response?.statusCode == 404 {
                        completionHandler(.success(false))
                        return
                    }
                    completionHandler(.failure(error))
                    return
                }
                completionHandler(.success(true))
        }
    }
    
    func starGist(_ gistId: String, completionHandler: @escaping (Error?) -> Void) {
        Alamofire.request(GistRouter.star(gistId))
            .response { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(authError)
                    return
                }
                
                if let error = response.error {
                    print(error)
                }
                completionHandler(response.error)
        }
    }
    
    func unstarGist(_ gistId: String, completionHandler: @escaping (Error?) -> Void) {
        Alamofire.request(GistRouter.unstar(gistId))
            .response { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(authError)
                    return
                }
                
                if let error = response.error {
                    print(error)
                }
                completionHandler(response.error)
        }
    }
    
    func deleteGist(_ gistId: String, completionHandler: @escaping (Error?) -> Void) {
        Alamofire.request(GistRouter.delete(gistId))
        .response { response in
            if let urlResponse = response.response,
                let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                completionHandler(authError)
                return
            }
            
            if let error = response.error {
                print(error)
            }
            self.clearCache()
            completionHandler(response.error)
        }
    }
    
    func createNewGist(description: String, isPublic: Bool, files: [File],
                       completionHandler: @escaping (Result<Bool>) -> Void) {
        
        let publicString = isPublic ? "true" : "false"
        var filesDictionary = [String: Any]()
        for file in files {
            if let name = file.filename,
                let content = file.content {
                filesDictionary[name] = ["content": content]
            }
        }
        
        let parameters: [String: Any] = [
            "description": description,
            "isPublic": publicString,
            "files": filesDictionary
        ]
        
        Alamofire.request(GistRouter.create(parameters))
            .response { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(.failure(authError))
                    return
                }
                
                if let error = response.error {
                    print(error)
                    if response.response?.statusCode == 404 {
                        completionHandler(.success(false))
                        return
                    }
                    completionHandler(.failure(error))
                    return
                }
                self.clearCache()
                completionHandler(.success(true))
        }
    }
    
    func updateGist(description: String, isPublic: Bool, files: [File],
                       completionHandler: @escaping (Result<Bool>) -> Void) {
        let publicString = isPublic ? "true" : "false"
        var filesDictionary = [String: Any]()
        for file in files {
            if let name = file.filename,
                let content = file.content {
                filesDictionary[name] = ["content": content]
            }
        }
        
        let parameters: [String: Any] = [
            "description": description,
            "isPublic": publicString,
            "files": filesDictionary
        ]
        
        //Alamofire.request(URLConvertible)
        
        Alamofire.request(GistRouter.update("uuu"))
            .response { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(.failure(authError))
                    return
                }
                
                if let error = response.error {
                    print(error)
                    if response.response?.statusCode == 404 {
                        completionHandler(.success(false))
                        return
                    }
                    completionHandler(.failure(error))
                    return
                }
                self.clearCache()
                completionHandler(.success(true))
        }
    }
    
    func printPublicGists() -> Void {
        Alamofire.request(GistRouter.getPublic())
            .responseJSON { response in
                print(self.gistArrayFromResponse(response: response))
        }
    }
    
    func fetchPublicGists(pageToLoad: String?, completionHandler:
        @escaping (Result<[Gist]>, String?) -> Void) {
        if let urlString = pageToLoad {
            fethGists(GistRouter.getAtPath(urlString), completionHandler: completionHandler)
        } else {
            fethGists(GistRouter.getPublic(), completionHandler: completionHandler)
        }
    }
    
    func fetchMyStarredGists(pageToLoad: String?, completionHandler:
        @escaping (Result<[Gist]>, String?) -> Void) {
        if let urlString = pageToLoad {
            fethGists(GistRouter.getAtPath(urlString), completionHandler: completionHandler)
        } else {
            fethGists(GistRouter.getMyStarred(), completionHandler: completionHandler)
        }
    }
    
    func fetchMyGists(pageToLoad: String?, completionHandler:
        @escaping (Result<[Gist]>, String?) -> Void) {
        if let urlString = pageToLoad {
            fethGists(GistRouter.getAtPath(urlString), completionHandler: completionHandler)
        } else {
            fethGists(GistRouter.getMine(), completionHandler: completionHandler)
        }
    }
    
    func fethGists(_ urlRequest: URLRequestConvertible, completionHandler:
        @escaping (Result<[Gist]>, String?) -> Void){
        Alamofire.request(urlRequest)
            .responseJSON(completionHandler: { response in
                if let urlResponse = response.response,
                    let authError = self.checkUnauthorized(urlResponse: urlResponse) {
                    completionHandler(.failure(authError), nil)
                    return
                }
                let result = self.gistArrayFromResponse(response: response)
                let next = self.parseNextPageFromHeaders(response: response.response)
                completionHandler(result, next)
            })
    }
    
    func imageFrom(urlString: String, completionHandler: @escaping (UIImage?, Error?) -> Void ){
        let _ = Alamofire.request(urlString)
            .response { dataResponse in
                guard let data = dataResponse.data else {
                    completionHandler(nil, dataResponse.error)
                    return
                }
                
                let image = UIImage(data: data)
                completionHandler(image, nil)
        }
    }
    
    private func parseNextPageFromHeaders(response: HTTPURLResponse?) -> String? {
        guard let linkHeader = response?.allHeaderFields["Link"] as? String else {
            return nil
        }
        
        let components = linkHeader.characters.split { $0 == "," }.map { String($0) }
        
        for item in components {
            
            let rangeOfNext = item.range(of: "rel=\"next\"", options: [])
            guard rangeOfNext != nil else {
                continue
            }
            
            let rangeOfPaddedURL = item.range(of: "<(.*)>;",
                                              options: .regularExpression,
                                              range: nil,
                                              locale: nil)
            guard let range = rangeOfPaddedURL else {
                return nil
            }
            
            let nextURL = item.substring(with: range)
            
            let start = nextURL.index(range.lowerBound, offsetBy: 1)
            let end = nextURL.index(range.upperBound, offsetBy: -2)
            let trimmedRange = start ..< end
            
            return nextURL.substring(with: trimmedRange)
        }
        
        return nil
    }
    
    private func gistArrayFromResponse(response: DataResponse<Any>) -> Result<[Gist]> {
        guard response.result.error == nil else {
            print(response.result.error!)
            return .failure(GitHubAPIManagerError.network(error: response.result.error!))
        }
        
        if let jsonDictionary = response.result.value as? [String: Any],
            let errorMessage = jsonDictionary["message"] as? String {
            return .failure(GitHubAPIManagerError.apiProvidedError(reason: errorMessage))
        }
        
        guard let jsonArray = response.result.value as? [[String: Any]] else {
            print("Error: didn't get array of gists object as JSON from API")
            return .failure(GitHubAPIManagerError.objectSerialization(reason:
                "Did not get JSON dictionary in response"))
        }
        
        let gists = jsonArray.flatMap { Gist(json: $0)}
        
        return .success(gists)
    }
    
}

enum GitHubAPIManagerError: Error {
    case network(error: Error)
    case apiProvidedError(reason: String)
    case authCouldNot(reason: String)
    case authLost(reason: String)
    case objectSerialization(reason: String)
}
