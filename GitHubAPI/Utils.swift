//
//  Utils.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 07.09.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import UIKit

extension UIImage {
    /**
     Resize UIImageView
     :param: new size CGSize
     :return: new UImage rezised
     */
    func resize (sizeChange:CGSize)-> UIImage?{
        
        let hasAlpha = true
        let scale: CGFloat = 0.0 // Use scale factor of main screen
        
        UIGraphicsBeginImageContextWithOptions(sizeChange, !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: sizeChange))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage
    }
    
}
