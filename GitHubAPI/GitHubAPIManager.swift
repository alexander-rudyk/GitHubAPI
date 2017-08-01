//
//  GitHubAPIManager.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation
import Alamofire

class GitHubAPIManager: NSObject {
    
    static let shared = GitHubAPIManager()
    
    func printPublicGists() -> Void {
        Alamofire.request(GistRouter.getPublic())
            .responseJSON { response in
                print(self.gistArrayFromResponse(response: response))
        }
    }
    
    func fetchPublicGists(completionHandler: @escaping (Result<[Gist]>) -> Void) {
        Alamofire.request(GistRouter.getPublic())
            .responseJSON(completionHandler: { response in
                let result = self.gistArrayFromResponse(response: response)
                completionHandler(result)
            })
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
