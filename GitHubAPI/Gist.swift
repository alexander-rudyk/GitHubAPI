//
//  Gist.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation

class Gist {
    
    var id: String?
    var description: String?
    var ownerLogin: String?
    var ownerAvatarURL: String?
    var url: String?
    
    required init() {
        
    }
    
    required init?(json: [String: Any]) {
        guard let description = json["description"] as? String,
            let idValue = json["id"] as? String,
            let url = json["url"] as? String else {
                return nil
        }
        
        self.description = description
        self.id = idValue
        self.url = url
        
        if let ownerJson = json["owner"] as? [String: Any] {
            self.ownerLogin = ownerJson["login"] as? String
            self.ownerAvatarURL = ownerJson["avatar_url"] as? String
        }
    }
}
