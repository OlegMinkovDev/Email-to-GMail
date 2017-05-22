//
//  ViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 20/02/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import ARSLineProgress

class ViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var serverNameTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var centerYConstraint: NSLayoutConstraint!
    
    var appDelegate = AppDelegate()
    
    let screenHeight = UIScreen.main.bounds.height
    var imapPopFolders = [MCOIMAPFolder]()
    var serverType = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        serverNameTextField.delegate = self
        portTextField.delegate = self
        userNameTextField.delegate = self
        passwordTextField.delegate = self
        
        let serverName = UserDefaults.standard.string(forKey: "server_name")
        let port = UserDefaults.standard.string(forKey: "port")
        let userName = UserDefaults.standard.string(forKey: "user_name")
        
        if serverName == nil {
            serverNameTextField.text = "imap.mail.me.com"
        } else { serverNameTextField.text = serverName! }
        if port == nil {
            portTextField.text = "993"
        } else { portTextField.text = port! }
        if userName == nil {
            userNameTextField.text = "yourname"
        } else { userNameTextField.text = userName! }
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        
        view.addGestureRecognizer(tap)
    }
    @IBAction func Authorization(_ sender: Any) {
        
        ARSLineProgress.show()
        
        appDelegate.currentServerName = self.serverNameTextField.text!
        
        if (serverNameTextField.text?.contains("imap"))! {
            
            serverType = "IMAP"
            getAllIMAPFolders()
            
        } else {
            
            serverType = "POP"
            getAllPOPMessages()
        }
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - TextField Delegate methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField == self.passwordTextField {
            
            if screenHeight == 480 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
            
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y - 90, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
            
            } else if screenHeight == 568 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y - 40, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
                
            }
        
        } else if textField == self.userNameTextField {
            
            if screenHeight == 480 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y - 40, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
                
            }
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField == self.passwordTextField {
            
            if screenHeight == 480 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y + 90, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
                
            } else if screenHeight == 568 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y + 40, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
            }
        
        } else if textField == self.userNameTextField {
            
            if screenHeight == 480 {
                
                contentView.translatesAutoresizingMaskIntoConstraints = true
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.contentView.frame = CGRect(x: self.contentView.frame.origin.x, y: self.contentView.frame.origin.y + 40, width: self.contentView.frame.size.width, height: self.contentView.frame.size.height)
                })
                
            }
        }
    }
    
    func getAllIMAPFolders() {
        
        self.appDelegate.imapSession = MCOIMAPSession()
        self.appDelegate.imapSession.hostname = self.serverNameTextField.text
        self.appDelegate.imapSession.username = self.userNameTextField.text
        self.appDelegate.imapSession.password = self.passwordTextField.text
        self.appDelegate.imapSession.port = UInt32(self.portTextField.text!)!
        self.appDelegate.imapSession.authType = .saslPlain
        self.appDelegate.imapSession.connectionType = .TLS
        
        let operation = appDelegate.imapSession.fetchAllFoldersOperation()
        operation?.start({ (error, folders) in
            
            if error == nil {
                
                // save data
                UserDefaults.standard.set(self.serverNameTextField.text, forKey: "server_name")
                UserDefaults.standard.set(self.portTextField.text, forKey: "port")
                UserDefaults.standard.set(self.userNameTextField.text, forKey: "user_name")
                
                for folder in folders as! [MCOIMAPFolder] {
                    self.imapPopFolders.append(folder)
                }
                
                ARSLineProgress.hide()
                
                self.performSegue(withIdentifier: "toGoogleSignIn", sender: self)
                
            } else {
                
                ARSLineProgress.hide()
                
                let alertController = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                
                alertController.addAction(alertAction)
                
                self.present(alertController, animated: true, completion: nil)
            }
        })
    }
    
    func getAllPOPMessages() {
        
        self.appDelegate.popSession = MCOPOPSession()
        self.appDelegate.popSession.hostname = self.serverNameTextField.text
        self.appDelegate.popSession.username = self.userNameTextField.text
        self.appDelegate.popSession.password = self.passwordTextField.text
        self.appDelegate.popSession.port = UInt32(self.portTextField.text!)!
        self.appDelegate.popSession.authType = .saslPlain
        self.appDelegate.popSession.connectionType = .TLS
        
        let operation = self.appDelegate.popSession.fetchMessagesOperation()
        operation?.start({ (error, messages) in
            
            if error == nil {
                
                // save data
                UserDefaults.standard.set(self.serverNameTextField.text, forKey: "server_name")
                UserDefaults.standard.set(self.portTextField.text, forKey: "port")
                UserDefaults.standard.set(self.userNameTextField.text, forKey: "user_name")
                
                self.appDelegate.allPopMessages = messages as! [MCOPOPMessageInfo]
                
                ARSLineProgress.hide()
                
                self.performSegue(withIdentifier: "toGoogleSignIn", sender: self)
                
            } else {
                
                ARSLineProgress.hide()
                
                let alertController = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                
                alertController.addAction(alertAction)
                
                self.present(alertController, animated: true, completion: nil)
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - Navigation
     
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
        if let viewController = segue.destination as? GoogleSignInViewController {
            viewController.imapPopFolders = self.imapPopFolders
            viewController.serverType = self.serverType
        }
    }
    
}

