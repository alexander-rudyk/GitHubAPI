//
//  GistRouter.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation
import Alamofire

enum GistRouter: URLRequestConvertible {
    static let baseURLString = "https://api.github.com/"
    
    case getPublic()
    case getMyStarred()
    case getMine()
    case getAtPath(String)
    case isStarred(String)
    case star(String)
    case unstar(String)
    case delete(String)
    case create([String: Any])
    case update(String)
    
    func asURLRequest() throws -> URLRequest {
        var method: HTTPMethod {
            switch self {
            case .getPublic, .getAtPath, .getMyStarred, .getMine, .isStarred:
                return .get
            case .star:
                return .put
            case .unstar, .delete:
                return .delete
            case .create:
                return .post
            case .update:
                return .patch
            }
        }
        
        let url: URL = {
            let relativePath: String
            switch self {
            case .getAtPath(let path):
                return URL(string: path)!
            case .getPublic():
                relativePath = "gists/public"
            case .getMyStarred:
                relativePath = "gists/starred"
            case .getMine:
                relativePath = "gists"
            case .isStarred(let id):
                relativePath = "gists/\(id)/star"
            case .star(let id):
                relativePath = "gists/\(id)/star"
            case .unstar(let id):
                relativePath = "gists/\(id)/star"
            case .delete(let id):
                relativePath = "gists/\(id)"
            case .create:
                relativePath = "gists"
            case .update(let id):
                relativePath = "gists/\(id)"
            }
            
            var url = URL(string: GistRouter.baseURLString)!
            url = url.appendingPathComponent(relativePath)
            return url
        }()
        
        let params: ([String: Any]?) = {
            switch self {
            case .getPublic, .getAtPath, .getMyStarred, .getMine, .isStarred, .star, .unstar, .delete, .update:
                return nil
            case .create(let params):
                return (params)
            }
        }()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        
        if let token = GitHubAPIManager.shared.OAuthToken {
            urlRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoding = JSONEncoding.default
        return try encoding.encode(urlRequest, with: params)
    }
    
    
}
