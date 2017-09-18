//
//  DetailViewController.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import UIKit
import SafariServices
import BRYXBanner
import PINRemoteImage

class DetailViewController: UIViewController {
    
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var starButton: UIBarButtonItem!
    
    var _isStarred: Bool?
    var isStarred: Bool? {
        get { return _isStarred}
        set {
            _isStarred = newValue
            if newValue == true {
                self.starButton.image = #imageLiteral(resourceName: "Star")
            } else {
                self.starButton.image = #imageLiteral(resourceName: "Unstar")
            }
        }
    }
    
    var alertController: UIAlertController?
    var errorBanner: Banner?
    
    func configureView() {
        // Update the user interface for the detail item.
        if let _ = self.gist {
            fetchStarredStatus()
            if let detailsView = self.tableView {
                detailsView.reloadData()
            }
        }
        
        tableView.separatorStyle = .none
    }
    
    func fetchStarredStatus() {
        guard let gistId = gist?.id else {
            return
        }
        GitHubAPIManager.shared.isGistStarred(gistId) { result in
            guard result.error == nil else {
                print(result.error!)
                switch result.error! {
                case GitHubAPIManagerError.authLost:
                    self.alertController = UIAlertController(title: "Could not get starred status",
                                                             message: result.error!.localizedDescription,
                                                             preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK",
                                                 style: .default,
                                                 handler: nil)
                    self.alertController?.addAction(okAction)
                    self.present(self.alertController!,
                                 animated: true,
                                 completion: nil)
                    return
                case GitHubAPIManagerError.network(let innerError as NSError):
                    if innerError.domain != NSURLErrorDomain {
                        break
                    }
                    if innerError.code == NSURLErrorNotConnectedToInternet {
                        self.showNotConnectedBanner(title: "Could not get star gist",
                                               message: "Sorry, you gist couldn't be starred. " +
                            "Maybe GitHub is down or you don't have an internet connection.")
                        return
                    }
                default:
                    break
                }
                return
            }
            if let status = result.value, self.isStarred == nil {
                self.isStarred = status
                //self.tableView.insertRows(at: [IndexPath(row: 2, section: 1)], with: .automatic)
            }
        }
    }
    
    func starThisGist() {
        guard let gistId = gist?.id else {
            return
        }
        GitHubAPIManager.shared.starGist(gistId) { (error) in
            if let error = error {
                print(error)
                let errorMessage: String?
                switch error {
                case GitHubAPIManagerError.authLost:
                    errorMessage = error.localizedDescription
                default:
                    errorMessage = "Sorry, you gist couldn't be starred." +
                    "Maybe GitHub is down or you don't have an internet connection. "
                    break
                }
                if let errorMessage = errorMessage {
                    self.alertController = UIAlertController(title: "Could not get star gist",
                                                             message: errorMessage,
                                                             preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK",
                                                 style: .default,
                                                 handler: nil)
                    self.alertController?.addAction(okAction)
                    self.present(self.alertController!,
                                 animated: true,
                                 completion: nil)
                }
            } else {
                self .isStarred = true
                //self.tableView.reloadRows(at: [IndexPath(row: 2, section: 1)], with: .automatic)
            }
        }
    }
    
    func unstarThisGist() {
        guard let gistId = gist?.id else {
            return
        }
        GitHubAPIManager.shared.unstarGist(gistId) { (error) in
            if let error = error {
                print(error)
                let errorMessage: String?
                switch error {
                case GitHubAPIManagerError.authLost:
                    errorMessage = error.localizedDescription
                default:
                    errorMessage = "Sorry, you gist couldn't be unstarred. " +
                    "Maybe GitHub is down or you don't have an internet connection."
                    break
                }
                if let errorMessage = errorMessage {
                    self.alertController = UIAlertController(title: "Could not get unstar gist",
                                                             message: errorMessage,
                                                             preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK",
                                                 style: .default,
                                                 handler: nil)
                    self.alertController?.addAction(okAction)
                    self.present(self.alertController!,
                                 animated: true,
                                 completion: nil)
                }
            } else {
                self .isStarred = false
                //self.tableView.reloadRows(at: [IndexPath(row: 2, section: 1)], with: .automatic)
            }
        }
    }
    
    @IBAction func starAction(_ sender: Any) {
        switch isStarred {
        case .some(true):
            unstarThisGist()
        case .some(false):
            starThisGist()
        default:
            return
        }
    }
    
    func showNotConnectedBanner(title: String, message: String) {
        self.errorBanner = Banner(title: title,
                                  subtitle: message,
                                  image: nil,
                                  backgroundColor: .orange,
                                  didTapBlock: nil)
        self.errorBanner?.dismissesOnSwipe = true
        self.errorBanner?.show(duration: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let existingBanner = self.errorBanner {
            existingBanner.dismiss()
        }
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var gist: Gist? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    
}

//MARK: - Table View
extension DetailViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        case 2:
            return gist?.files?.count ?? 0
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        case 0:
            return nil
        case 1:
            return "About"
        case 2:
            return "Files"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AutorCell", for: indexPath) as! AutorTableViewCell
            
            cell.autorNameLabel.text = gist?.ownerLogin
            
            if let urlString = gist?.ownerAvatarURL,
                let url = URL(string: urlString) {
                let placeholderImage = #imageLiteral(resourceName: "placeholder")
                cell.avatarImageView.pin_setImage(from: url, placeholderImage: placeholderImage) {
                    result in
                    
                    if let cellToUpdate = self.tableView?.cellForRow(at: indexPath) {
                        cellToUpdate.setNeedsLayout()
                    }
                }
            } else {
                let placeholderImage = #imageLiteral(resourceName: "placeholder")
                cell.avatarImageView.image = placeholderImage
            }
            
            cell.avatarImageView.layer.cornerRadius = cell.avatarImageView.bounds.height / 2
            cell.avatarImageView.layer.masksToBounds = true
            
            
            
            return cell
        }
        
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        switch (indexPath.section, indexPath.row, isStarred) {
        case (1, 0, _):
            cell.textLabel?.text = gist?.gistDescription
        case (1, 1, _):
            cell.textLabel?.text = gist?.ownerLogin
        case (1, 2, .none):
            cell.textLabel?.text = ""
        case (1, 2, .some(true)):
            cell.textLabel?.text = "Unstar"
        case (1, 2, .some(false)):
            cell.textLabel?.text = "Star"
        default:
            cell.textLabel?.text = gist?.files?[indexPath.row].filename
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch (indexPath.section, indexPath.row, isStarred) {
        case (1, 2, .some(true)):
            unstarThisGist()
        case (1, 2, .some(false)):
            starThisGist()
        case (2, _, _):
            guard let file = gist?.files?[indexPath.row],
                let urlString = file.raw_url,
                let url = URL(string: urlString) else {
                    return
            }
            let safariViewController = SFSafariViewController(url: url)
            safariViewController.title = file.filename
            self.navigationController?.pushViewController(safariViewController, animated: true)
        default:
            print("No-op")
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 220
        default:
            return 44
        }
    }
}

