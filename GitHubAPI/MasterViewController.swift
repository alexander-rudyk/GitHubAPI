//
//  MasterViewController.swift
//  GitHubAPI
//
//  Created by Alexander Ruduk on 01.08.17.
//  Copyright © 2017 Alexander Ruduk. All rights reserved.
//

import UIKit
import PINRemoteImage
import SafariServices
import Alamofire
import BRYXBanner
import AVFoundation

class MasterViewController: UITableViewController, LoginViewDelegate {
    
    var errorBanner: Banner?
    
    var safariViewController: SFSafariViewController?
    
    var dateFormatter = DateFormatter()
    var detailViewController: DetailViewController? = nil
    var gists = [Gist]()
    var nextPageURLString: String?
    var isLoaded = false
    
    @IBOutlet weak var gistSegmentedControl: UISegmentedControl!
    
    func setBackground(with image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        let blur = UIBlurEffect(style: .regular)
        let effectView = UIVisualEffectView(effect: blur)
        effectView.frame = view.bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.addSubview(effectView)
        self.tableView.backgroundView = imageView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (!GitHubAPIManager.shared.isLoadingOAuthToken) {
            loadInitialData()
        }
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        setBackground(with: #imageLiteral(resourceName: "background"))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        
        if (self.refreshControl == nil) {
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
            self.refreshControl?.addTarget(self,
                                           action: #selector(refresh(sender:)),
                                           for: .valueChanged)
            self.dateFormatter.dateStyle = .short
            self.dateFormatter.timeStyle = .long
        }
        
        let now = Date()
        let updateString = "Last Updated at " + self.dateFormatter.string(from: now)
        self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //loadGists(urlToLoad: nil)
        if (!GitHubAPIManager.shared.isLoadingOAuthToken) {
            loadInitialData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let existingBanner = self.errorBanner {
            existingBanner.dismiss()
        }
        super.viewWillDisappear(animated)
    }
    
    func loadInitialData() {
        isLoaded = true
        GitHubAPIManager.shared.OAuthTokenCompletionHandler = { error in
            guard error == nil else {
                print(error!)
                self.isLoaded = false
                self.showOAuthLoginView()
                return
            }
            if let _ = self.safariViewController {
                self.dismiss(animated: false) {}
            }
            self.loadGists(urlToLoad: nil)
        }
        
        if (!GitHubAPIManager.shared.hasOAuthToken()) {
            showOAuthLoginView()
            return
        }
        loadGists(urlToLoad: nil)
    }
    
    func showOAuthLoginView() {
        GitHubAPIManager.shared.isLoadingOAuthToken = true
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        guard let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else {
            assert(false, "Misnamed view controller")
            return
        }
        loginVC.delegate = self
        self.present(loginVC, animated: true, completion: nil)
    }
    
    func showNotConnectedBanner() {
        // sow not connected error & tell em to try again when they do have a connection
        // check for existing banner
        if let existingBanner = self.errorBanner {
            existingBanner.dismiss()
        }
        
        self.errorBanner = Banner(title: "No internet Connection",
                                  subtitle: "Could not load gists. Try again when you're connected to the internet.",
                                  image: nil,
                                  backgroundColor: .red,
                                  didTapBlock: nil)
        self.errorBanner?.dismissesOnSwipe = true
        self.errorBanner?.show(duration: nil)
    }
    
    func showOfflineSaveFailedBanner() {
        if let existingBanner = self.errorBanner {
            existingBanner.dismiss()
        }
        self.errorBanner = Banner(title: "Could not save gists to view offline",
                                  subtitle: "Your iOS device is almost out of free space. \n" +
            "You will only be able to see gists when you have an internet conection",
                                  image: nil,
                                  backgroundColor: UIColor.orange,
                                  didTapBlock: nil)
        self.errorBanner?.dismissesOnSwipe = true
        self.errorBanner?.show()
    }
    
    func didTapLoginButton() {
        self.dismiss(animated: false) { 
            guard let authURL = GitHubAPIManager.shared.URLToStartOAuth2Login() else {
                let error = GitHubAPIManagerError.authCouldNot(reason:
                "Could not obtain an OAuth token")
                GitHubAPIManager.shared.OAuthTokenCompletionHandler?(error)
                return
            }
            self.safariViewController = SFSafariViewController(url: authURL)
            self.safariViewController?.delegate = self
            guard let webViewController = self.safariViewController else {
                return
            }
            self.present(webViewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
        // clear out the table view
        gists = []
        tableView.reloadData()
        
        // only show add button for my gists
        if (gistSegmentedControl.selectedSegmentIndex == 2) {
            self.navigationItem.leftBarButtonItem = self.editButtonItem
            let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                            target: self,
                                            action: #selector(insertNewObject(_:)))
            navigationItem.rightBarButtonItem = addButton
        } else {
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
        }
        
        loadGists(urlToLoad: nil)
    }
    
    func loadGists(urlToLoad: String?) {
        self.isLoaded = true
        let completionHandler: (Result<[Gist]>, String?) -> Void = {
            (result, nextPage) in
            self.isLoaded = false
            self.nextPageURLString = nextPage
            
            if self.refreshControl != nil,
                self.refreshControl!.isRefreshing {
                self.refreshControl?.endRefreshing()
            }
            
            guard result.error == nil else {
                self.handleLoadGistError(result.error!)
                return
            }
            
            guard let fetchedGists = result.value else {
                print("no gists fetched")
                return
            }
            
            if urlToLoad == nil {
                self.gists = []
            }
            
            self.gists += fetchedGists
            
            let path:Path = [.Public, .Starred, .MyGists][self.gistSegmentedControl.selectedSegmentIndex]
            
            let success = PersistenceManager.saveArray(arrayToSave: self.gists, path: path)
            if !success {
                self.showOfflineSaveFailedBanner()
            }
            
            self.tableView.reloadData()
        }
        
        switch gistSegmentedControl.selectedSegmentIndex {
        case 0:
            GitHubAPIManager.shared.fetchPublicGists(pageToLoad: urlToLoad,
                                                     completionHandler: completionHandler)
        case 1:
            GitHubAPIManager.shared.fetchMyStarredGists(pageToLoad: urlToLoad,
                                                        completionHandler: completionHandler)
        case 2:
            GitHubAPIManager.shared.fetchMyGists(pageToLoad: urlToLoad,
                                                        completionHandler: completionHandler)
        default:
            print("got an index that I didn't expect for selectedSegmentIndex")
        }
    }
    
    func refresh(sender: Any) {
        GitHubAPIManager.shared.isLoadingOAuthToken = false
        GitHubAPIManager.shared.clearCache()
        nextPageURLString = nil
        loadInitialData()
    }
    
    func handleLoadGistError(_ error: Error) {
        print(error)
        nextPageURLString = nil
        
        isLoaded = false
        
        self.isLoaded = false
        switch error {
        case GitHubAPIManagerError.authLost:
            self.showOAuthLoginView()
            return
        case GitHubAPIManagerError.network(let innerError as NSError):
            if innerError.domain != NSURLErrorDomain {
                break
            }
            if innerError.code == NSURLErrorNotConnectedToInternet {
                let path: Path = [.Public, .Starred, .MyGists][self.gistSegmentedControl.selectedSegmentIndex]
                if let archived: [Gist] = PersistenceManager.loadArray(path: path) {
                    self.gists = archived
                } else {
                    self.gists = []
                }
                self.tableView.reloadData()
                
                showNotConnectedBanner()
                return
            }
        default:
            break
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func insertNewObject(_ sender: Any) {
        let createVC = CreateGistViewController(nibName: nil, bundle: nil)
        self.navigationController?.pushViewController(createVC, animated: true)
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let gist = gists[indexPath.row]
                if let controller = (segue.destination as? UINavigationController)?.topViewController as? DetailViewController {
                    controller.gist = gist
                    controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                    controller.navigationItem.leftItemsSupplementBackButton = true
                }
            }
        }
    }
    
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let gist = gists[indexPath.row]
        cell.textLabel!.text = gist.gistDescription
        cell.detailTextLabel?.text = gist.ownerLogin
        
        cell.imageView?.image = nil
        if let urlString = gist.ownerAvatarURL,
            let url = URL(string: urlString) {
            let placeholderImage = #imageLiteral(resourceName: "placeholder")
            cell.imageView?.pin_setImage(from: url, placeholderImage: placeholderImage) {
                result in
                
                if let cellToUpdate = self.tableView?.cellForRow(at: indexPath) {
                    cellToUpdate.setNeedsLayout()
                }
            }
        } else {
            let placeholderImage = #imageLiteral(resourceName: "placeholder")
            cell.imageView?.image = placeholderImage
        }
        
        if !isLoaded {
            let rowsLoaded = gists.count
            let rowsRemaining = rowsLoaded - indexPath.row
            let rowsToLoadFromBottom = 5
            
            if rowsRemaining <= rowsToLoadFromBottom {
                if let nextPage = nextPageURLString {
                    print("nextPage: \(nextPage), nextPageURLString: \(nextPageURLString!)")
                    self.loadGists(urlToLoad: nextPage)
                }
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // only allow editing my gists
        return gistSegmentedControl.selectedSegmentIndex == 2
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let gistToDelete = gists[indexPath.row]
            guard let idToDelete = gistToDelete.id else {
                return
            }
            // remove from array of gists
            gists.remove(at: indexPath.row)
            // remove table view row
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // delete from GitHub
            GitHubAPIManager.shared.deleteGist(idToDelete, completionHandler: { error in
                if let error = error {
                    print(error)
                    // Put it back
                    self.gists.insert(gistToDelete, at: indexPath.row)
                    tableView.insertRows(at: [indexPath], with: .right)
                    // tell them it didn't work
                    let alertController = UIAlertController(title: "Could not delete gist",
                                                            message: "Sorry, your gist couldn't be deleted. Maybe GitHub is "
                                                                + "down or you don't have an internet connection",
                                                            preferredStyle: .alert)
                    // add ok button
                    let okButton = UIAlertAction(title: "OK",
                                                 style: .default,
                                                 handler: nil)
                    alertController.addAction(okButton)
                    // show the alert
                    self.present(alertController,
                                 animated: true,
                                 completion: nil)
                }
            })
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    
}

extension MasterViewController: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if (!didLoadSuccessfully) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}

