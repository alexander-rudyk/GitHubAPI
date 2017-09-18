//
//  MashapeRouter.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 16.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation
import Alamofire

enum MashapeRouter: URLRequestConvertible {
    static let baseUrlString = "https://mashape-community-urban-dictionary.p.mashape.com/"
    
    case getDefinition(String)
    
    func asURLRequest() throws -> URLRequest {
        var method: HTTPMethod {
            switch self {
            case .getDefinition:
                return .get
            }
        }
        
        let url: URL = {
            let relativePath: String
            switch self {
            case .getDefinition:
                relativePath = "define"
            }
            
            var url = URL(string: MashapeRouter.baseUrlString)!
            url.appendPathComponent(relativePath)
            return url
        }()
        
        let params: ([String: Any]?) = {
            switch self {
            case .getDefinition(let wordToDefine):
                return ["term": wordToDefine]
            }
        }()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("MY_API_KEY", forHTTPHeaderField: "X-Mashape-Key")
        
        let encoding = URLEncoding.default
        return try encoding.encode(urlRequest, with: params)
    }
}

