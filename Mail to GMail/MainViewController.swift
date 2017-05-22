//
//  MainViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 23/02/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import ARSLineProgress
import BugfenderSDK
import GoogleAPIClientForREST

enum Action {
    case Move
    case Copy
}

enum Failure {
    case Retry
    case Skip
    case Ask
}

class Mail {
    
    var fromMail = String()
    var toMail = String()
    var fromDisplayName = String()
    var toDisplayName = String()
    var date = Date()
    var subject = String()
    var body = String()
    var attachment: [String]? = [String]()
}

class MainViewController: UIViewController {

    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var processedYConstraint: NSLayoutConstraint!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var totalMessagesLabel: UILabel!
    @IBOutlet weak var moveCopySegmentedControl: UISegmentedControl!
    @IBOutlet weak var onFailureSegmentedControl: UISegmentedControl!
	@IBOutlet weak var progressLabel: UILabel!
	@IBOutlet weak var buttonStart: UIButton!
    
    var appDelegate = AppDelegate()
    var sourceFolder = String()
    var targetFolder = GTLRGmail_Label()
    var serverType = String()
    
    private var action: String? = String()
    private var failure: String? = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate = UIApplication.shared.delegate as! AppDelegate

        sourceLabel.text = sourceFolder
        targetLabel.text = targetFolder.name!
        
        // if iPhone4
        if UIScreen.main.bounds.size.height == 480 {
            self.topConstraint.constant = 0
        }
        
        self.title = "Compose"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
		
		showLoader(withLabel: true)
        getAllMessages()
    }
    
    @IBAction func Start(_ sender: Any)
	{
		if !progressLabel.isHidden { return }
		
		BFLog("StartButton | Start")
		
        self.action = self.moveCopySegmentedControl.titleForSegment(at: self.moveCopySegmentedControl.selectedSegmentIndex)
        self.failure = self.onFailureSegmentedControl.titleForSegment(at: self.onFailureSegmentedControl.selectedSegmentIndex)
		
		let key = self.appDelegate.currentServerName + "_" + sourceFolder + "_" + targetFolder.identifier!
		let lastKey = UserDefaults.standard.string(forKey: "k_LastKey")
		
		if key != lastKey && lastKey != nil
		{
			UserDefaults.standard.set(nil, forKey: lastKey!)
		}
		
		self.performSegue(withIdentifier: "toCopyMove", sender: self)
    }
    
    @IBAction func Cancel(_ sender: Any) {
		
        BFLog("CancelButton | Start")
        
        hideLoader()
        
        let navigationController = self.storyboard?.instantiateViewController(withIdentifier: "NavID") as! UINavigationController
        self.present(navigationController, animated: true, completion: nil)
    }
	
	func showLoader(withLabel: Bool) {
        
		ARSLineProgress.show()
		//progressLabel.text = "Processed: 0"
		//progressLabel.isHidden = !withLabel
	}
	
	func hideLoader() {
		ARSLineProgress.hide()
		progressLabel.isHidden = true
	}
    
    func getAllMessages() {
		
		BFLog("getAllMessages | Start")
		
        if self.serverType == "IMAP" {
            
            let operation = self.appDelegate.imapSession.folderStatusOperation("INBOX")
            operation?.start({ (error, folderStatus) in
                
                guard let status = folderStatus else {
                    BFLog("Error folder status: \(error!.localizedDescription)")
                    self.hideLoader()
                    return
                }
                
                self.hideLoader()
                self.totalMessagesLabel.text = String(status.messageCount)
            })
			
        } else {
			
            DispatchQueue.main.async {
				
				BFLog("getAllMessages | Not IMAP")
                
                self.totalMessagesLabel.text = self.appDelegate.allPopMessages.count.description
                self.hideLoader()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
		BFLog("\(self.description) didReceiveMemoryWarning !!!!!!!!!!!!")
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? CopyMoveViewController {
            viewController.targetFolder = self.targetFolder
            viewController.sourceFolder = self.sourceFolder
            viewController.serverType = self.serverType
            
            if failure! == "RETRY" {
                viewController.failure = .Retry
            } else if failure! == "SKIP" {
                viewController.failure = .Skip
            } else {
                viewController.failure = .Ask
            }
            
            if action! == "Move" {
                viewController.action = .Move
            } else {
                viewController.action = .Copy
            }
        }
    }
    

}
