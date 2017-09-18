//
//  LoginViewController.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 21.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import UIKit

protocol LoginViewDelegate: class {
    func didTapLoginButton()
}

class LoginViewController: UIViewController {
    weak var delegate: LoginViewDelegate?

    @IBAction func tappedLoginButton() {
        delegate?.didTapLoginButton()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}
