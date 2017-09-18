//
//  Gist.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import Foundation

class Gist: NSObject, NSCoding {
    
    var id: String?
    var gistDescription: String?
    var ownerLogin: String?
    var ownerAvatarURL: String?
    var url: String?
    var files: [File]?
    var createdAt: Date?
    var updatedAt: Date?
    
    required override init() {
        
    }
    
    required init?(json: [String: Any]) {
        guard let gistDescription = json["description"] as? String,
            let idValue = json["id"] as? String,
            let url = json["url"] as? String else {
                return nil
        }
        self.gistDescription = gistDescription
        self.id = idValue
        self.url = url
        
        if let ownerJson = json["owner"] as? [String: Any] {
            self.ownerLogin = ownerJson["login"] as? String
            self.ownerAvatarURL = ownerJson["avatar_url"] as? String
        }
        
        self.files = [File]()
        if let filesJSON = json["files"] as? [String: [String:Any]] {
            for (_, fileJSON) in filesJSON {
                if let newFile = File(json: fileJSON) {
                    self.files?.append(newFile)
                }
            }
        }
        
        //Dates
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let dateString = json["created_at"] as? String {
            self.createdAt = dateFormatter.date(from: dateString)
        }
        if let dateString = json["updated_at"] as? String {
            self.updatedAt = dateFormatter.date(from: dateString)
        }
    }
    
    //MARK: NSCoding
    @objc func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        aCoder.encode(self.gistDescription, forKey: "gistDescription")
        aCoder.encode(self.ownerLogin, forKey: "ownerLogin")
        aCoder.encode(self.ownerAvatarURL, forKey: "ownerAvatarURL")
        aCoder.encode(self.url, forKey: "url")
        aCoder.encode(self.createdAt, forKey: "createdAt")
        aCoder.encode(self.updatedAt, forKey: "updatedAt")
        if let files = self.files {
            aCoder.encode(files, forKey: "files")
        }
    }
    
    @objc required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        
        self.id = aDecoder.decodeObject(forKey: "id") as? String
        self.gistDescription = aDecoder.decodeObject(forKey: "gistDescription") as? String
        self.ownerLogin = aDecoder.decodeObject(forKey: "ownerLogin") as? String
        self.ownerAvatarURL = aDecoder.decodeObject(forKey: "ownerAvatarURl") as? String
        self.createdAt = aDecoder.decodeObject(forKey: "createdAt") as? Date
        self.updatedAt = aDecoder.decodeObject(forKey: "updatedAt") as? Date
        if let files = aDecoder.decodeObject(forKey: "files") as? [File] {
            self.files = files
        }
    }
}
