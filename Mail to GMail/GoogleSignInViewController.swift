//
//  GoogleSignInViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 21/02/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST
import ARSLineProgress
import BugfenderSDK

class GoogleSignInViewController: UIViewController, GIDSignInUIDelegate, GIDSignInDelegate {
    
    var appDelegate = AppDelegate()
    
    var imapPopFolders = [MCOIMAPFolder]()
    var gmailLabels = [GTLRGmail_Label]()
    var serverType = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let composeScope = "https://www.googleapis.com/auth/gmail.labels";
        let insertScope = "https://www.googleapis.com/auth/gmail.insert"
        let modifyScope = "https://www.googleapis.com/auth/gmail.modify"
        var currentScopes = GIDSignIn.sharedInstance().scopes
        currentScopes?.append(composeScope)
        currentScopes?.append(insertScope)
        currentScopes?.append(modifyScope)
		
		GIDSignIn.sharedInstance().disconnect() /// disconnect user
		
        GIDSignIn.sharedInstance().scopes = currentScopes

        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = self
        
        self.title = "GMail Authorization"
    }
    
    @IBAction func GoogleSignInPress(_ sender: Any) {
    
        // ARSLineProgress.show()
    }
    
    // Construct a query and get a list of upcoming labels from the gmail API
    func fetchLabels() {
        
        let querty = GTLRGmailQuery_UsersLabelsList.query(withUserId: "me")
        appDelegate.service.executeQuery(querty, delegate: self, didFinish: #selector(displayResultWithTicket))
        
        
    }
    
    // Display the labels in the UITextView
    func displayResultWithTicket(ticket : GTLRServiceTicket,
                                 finishedWithObject labelsResponse : GTLRGmail_ListLabelsResponse,
                                 error : NSError?) {
		
		ARSLineProgress.hide()
		
        if let error = error {
            BFLog(error.localizedDescription)
            return
        }
		
        if (labelsResponse.labels?.count)! > 0 {
			self.gmailLabels = labelsResponse.labels!
		}
			
		
		self.performSegue(withIdentifier: "toShowFolders", sender: self)
		
    }
    
    // MARK: - GIDSignInDelegate
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        
        if (error == nil) {
            
            self.appDelegate.gmail = user.profile.email
            self.appDelegate.gmailFullName = user.profile.name
            
            self.appDelegate.service.authorizer = user.authentication.fetcherAuthorizer()
            
            if let authorizer = self.appDelegate.service.authorizer,
                let canAuth = authorizer.canAuthorize, canAuth {
                
                self.fetchLabels()
                
            } else {
                BFLog("Google auth error")
            }
            
        } else {
            BFLog("\(error.localizedDescription)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let viewController = segue.destination as? ShowFolderViewController {
            viewController.imapPopFolders = self.imapPopFolders
            viewController.gmailLabels = self.gmailLabels
            viewController.serverType = self.serverType
        }
    }

}
