//
//  ShowFolderViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 21/02/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST

class ShowFolderViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var imapPopFolders = [MCOIMAPFolder]()
    var gmailLabels = [GTLRGmail_Label]()
    var sourceFolder = String()
    var serverType = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        self.title = "IMAP / POP FOLDER"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if self.serverType == "IMAP" {
            return self.imapPopFolders.count
        } else { return 1 }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        
        if self.serverType == "IMAP" {
            cell?.textLabel?.text = self.imapPopFolders[indexPath.row].path!
        } else {
            cell?.textLabel?.text = "All Emails"
        }
        
        cell?.backgroundColor = UIColor.init(red: 206/255, green: 206/255, blue: 206/255, alpha: 1)
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if self.serverType == "IMAP" {
            self.sourceFolder = imapPopFolders[indexPath.row].path!
        } else {
            self.sourceFolder = "All Emails"
        }
        
        self.performSegue(withIdentifier: "toShowLabels", sender: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let viewController = segue.destination as? ShowLabelViewController {
            viewController.gmailLabels = self.gmailLabels
            viewController.sourceFolder = self.sourceFolder
            viewController.serverType = self.serverType
        }
    }
    

}
