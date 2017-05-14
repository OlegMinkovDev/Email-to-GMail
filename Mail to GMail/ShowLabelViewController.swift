//
//  ShowLabelViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 23/02/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST

class ShowLabelViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var gmailLabels = [GTLRGmail_Label]()
    var sourceFolder = String()
    var targetLabel = GTLRGmail_Label()
    var serverType = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        self.title = "Folder from GMail"
    }
    
    // MARK: - TableView delegate methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gmailLabels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        
        cell?.backgroundColor = UIColor.init(red: 206/255, green: 206/255, blue: 206/255, alpha: 1)
        cell?.textLabel?.text = gmailLabels[indexPath.row].name!
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        targetLabel = gmailLabels[indexPath.row]
        self.performSegue(withIdentifier: "toMain", sender: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let viewController = segue.destination as? MainViewController {
            viewController.sourceFolder = self.sourceFolder
            viewController.targetFolder = self.targetLabel
            viewController.serverType = self.serverType
        }
    }
    

}
