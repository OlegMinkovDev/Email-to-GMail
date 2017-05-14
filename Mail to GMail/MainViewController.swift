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
    
    private var allIMAPMessages = [MCOIMAPMessage]()
    private var action: String? = String()
    private var failure: String? = String()
    private var partOfMessages = 10
    
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
        self.getAllMessages()
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
		progressLabel.text = "Processed: 0"
		progressLabel.isHidden = !withLabel
	}
	
	func hideLoader() {
		ARSLineProgress.hide()
		progressLabel.isHidden = true
	}
    
    func getAllMessages() {
		
		BFLog("getAllMessages | Start")
		
        if self.serverType == "IMAP" {
        
            let requestKind:MCOIMAPMessagesRequestKind = [.headers, .structure, .extraHeaders, .internalDate, .fullHeaders] // flags, structure
            let uids = MCOIndexSet.init(range: MCORangeMake(1, UInt64(partOfMessages - 1)))
            
            let operation = appDelegate.imapSession.fetchMessagesByNumberOperation(withFolder: sourceFolder, requestKind: requestKind, numbers: uids)
			
			operation?.progress = { [weak self] number in
				self?.progressLabel.text = "Processed: \(number)"
			}
			
			BFLog("Send request to fetched messages")
			
            operation?.start({ [weak self] (error, fetchedMessages, vanishedMessages) in
                
                if error == nil
				{
					if let messages = fetchedMessages
					{
						self?.allIMAPMessages = messages as! [MCOIMAPMessage]
						
						BFLog("getAllMessages | Receive: \(self?.allIMAPMessages.count ?? 0)")
                        
                        if self!.allIMAPMessages.count >= self!.partOfMessages {
                            self?.totalMessagesLabel.text = "More then \(self!.partOfMessages) letters"
                        } else {
                            self?.totalMessagesLabel.text = self?.allIMAPMessages.count.description
                        }
					}
					
                    self?.hideLoader()
					self?.buttonStart.isUserInteractionEnabled = true
                }
				else
				{
                    print("Error fetches messages: \(error!.localizedDescription)")
					BFLog("Error fetches messages: \(error!.localizedDescription)")
					
					self?.hideLoader()
					self?.buttonStart.isUserInteractionEnabled = false
					
					let alertController = UIAlertController(title: "Error", message: error!.localizedDescription, preferredStyle: .alert)
					let skipAction = UIAlertAction(title: "OK", style: .default, handler: { (skip) in
						self?.navigationController?.popViewController(animated: true)
					})
					alertController.addAction(skipAction)
					self?.present(alertController, animated: true, completion: nil)
                }
            })
			
        } else {
			
            DispatchQueue.main.async {
				
				BFLog("getAllMessages | Not IMAP")
				
                if self.appDelegate.allPopMessages.count >= self.partOfMessages {
                    self.totalMessagesLabel.text = "More then \(self.partOfMessages) letters"
                } else {
                    self.totalMessagesLabel.text = self.appDelegate.allPopMessages.count.description
                }
                
                self.totalMessagesLabel.text = String(self.appDelegate.allPopMessages.count)
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
            viewController.allImapMessages = self.allIMAPMessages
            viewController.serverType = self.serverType
            viewController.partOfMessages = self.partOfMessages
            
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
