//
//  AutorTableViewCell.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 11.09.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import UIKit

class AutorTableViewCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var autorNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
