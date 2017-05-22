//
//  CopyMoveViewController.swift
//  Mail to GMail
//
//  Created by Oleg Minkov on 03/03/2017.
//  Copyright © 2017 Oleg Minkov. All rights reserved.
//

import UIKit
import LDProgressView
import GoogleAPIClientForREST
import BugfenderSDK

class CopyMoveViewController: UIViewController {
    
    @IBOutlet weak var currentMessageLabel: UILabel!
    @IBOutlet weak var messageUIDLabel: UILabel!
	@IBOutlet weak var messageSubjectLabel: UILabel!
    @IBOutlet weak var allPrecessDoneLabel: UILabel!
    @IBOutlet weak var successfullMessagesLabel: UILabel!
    @IBOutlet weak var failureMessagesLabel: UILabel!
    @IBOutlet weak var skippedMessagesLabel: UILabel!

    var appDelegate = AppDelegate()
    var sourceFolder = String()
    var targetFolder = GTLRGmail_Label()
    var allImapMessages = [MCOIMAPMessage]()
    var allPopMessages = [MCOPOPMessageInfo]()
    var action = Action.Move
    var failure = Failure.Retry
    var serverType = String()
	var stopFlag = false
	let dateFormatter = DateFormatter()
    var parser: MCOMessageParser!
    var messageUID = UInt32()
    
    private var mail = Mail()
    private var ldProgressView = LDProgressView()
    private var globalMessageIndex = 0
    private var successfulCount = 0
    private var skippedCount = 0
    private var retryAndSkipCount = 3
    private var successfullUdidsArray:[UInt32]? = [UInt32]()
    private var partMessageIndex = 1
    private var allMessageCount = 0
    
    private var partOfMessages = 10 // choose desired count
    private var startMessagesIndex = 1
    private var endMessagesIndex = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        appDelegate = UIApplication.shared.delegate as! AppDelegate

        ldProgressView = LDProgressView(frame: CGRect(x: 20, y: 128, width: view.frame.size.width - 40, height: 25))
        ldProgressView.progress = 0
        ldProgressView.color = UIColor.init(colorLiteralRed: 0, green: 0.64, blue: 0, alpha: 1)
        ldProgressView.flat = true
        ldProgressView.animate = true
        ldProgressView.showText = false
        ldProgressView.showStroke = false
        ldProgressView.progressInset = 5
        ldProgressView.showBackground = false
        ldProgressView.outerStrokeWidth = 3
        ldProgressView.type = LDProgressSolid
        view.addSubview(ldProgressView)
		
		dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        if serverType == "IMAP" {
            allMessageCount = allImapMessages.count
            currentMessageLabel.text = "\(successfulCount) out of \(allImapMessages.count)"
        } else {
            allMessageCount = appDelegate.allPopMessages.count
            currentMessageLabel.text = "\(successfulCount) out of \(appDelegate.allPopMessages.count)"
        }
        
        endMessagesIndex = partOfMessages
        
        parseMessages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        allPrecessDoneLabel.isHidden = true
        successfullMessagesLabel.isHidden = true
        failureMessagesLabel.isHidden = true
        skippedMessagesLabel.isHidden = true
    }
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		stopFlag = true
	}
    
    func getFormattedRawMessage(parser: MCOMessageParser, mail: Mail) -> Data
    {
		BFLog("getFormattedRawMessage | Start")
        // Date string
        let strDate = dateFormatter.string(from: mail.date)
        let finalDate = "Date: " + strDate + "\r\n"
        
        // From string
        let from = "From: \(mail.fromDisplayName) <\(mail.fromMail)>\r\n";
        
        // To string
        let to = "To: \(mail.toDisplayName) <\(mail.toMail)>\r\n";
        
        // CC string
        let cc = "";
        
        // BCC string
        let bcc = "";
        
        // Subject string
        var subject = "Subject: \(mail.subject)\r\n\r\n"
        subject = subject.replacingOccurrences(of: "«", with: "\"")
        subject = subject.replacingOccurrences(of: "»", with: "\"")
        subject = subject.replacingOccurrences(of: "і", with: "i")
        subject = subject.replacingOccurrences(of: "ї", with: "i")
        subject = subject.replacingOccurrences(of: "є", with: "е")
        subject = subject.replacingOccurrences(of: "ґ", with: "г")
        
        // Body string
        let body:String? = parser.htmlBodyRendering() // "\(mail.body)\r\n";
        
        // Final string to be returned
        var rawMessage = "";
        
        // Send as "multipart/mixed" alternative
        let contentTypeMain = "Content-Type: multipart/mixed; boundary=\"project\"\r\n";
        
        // Reusable Boundary string
        let boundary = "\r\n--project\r\n";
        
        // Body string
        let contentTypePlain = "Content-Type: text/html; charset=\"UTF-8\"\r\n"
        
        // Combine strings from "finalDate" to "body"
        rawMessage = contentTypeMain + finalDate + from + to + cc + bcc + subject
        let firstPartData = rawMessage.data(using: .iso2022JP)
        
        var continueRawMessage = boundary + contentTypePlain
		
		if let bodyN = body {
			continueRawMessage = continueRawMessage + bodyN
		}
        
        if (mail.attachment?.count)! > 0 {
            for content in mail.attachment! {
                continueRawMessage += content
            }
        }
        
        // End string
        continueRawMessage += "\r\n--project--"
        
        // print(continueRawMessage)
        
        let secondPartData = continueRawMessage.data(using: .utf8)
		
		if let first = firstPartData, let second = secondPartData {
            
			BFLog("getFormattedRawMessage first + second | End")
            return first + second
		}
		else if let first = firstPartData
		{
			BFLog("getFormattedRawMessage first | End")
			return first
		}
		else if let second = secondPartData
		{
			BFLog("getFormattedRawMessage second | End")
			return second
		}
		
		BFLog("ERROR WHILE CREATE RAW DATA !!!! \nMESSAGE_FROM: \(mail.fromMail) \nMESSAGE_Subject: \(mail.subject)")
		
		return Data()
    }
    
    func loadIMAPMessages() {
        
        partMessageIndex += partOfMessages
        
        let requestKind:MCOIMAPMessagesRequestKind = [.headers, .structure, .extraHeaders, .internalDate, .fullHeaders] // flags, structure
        
        let uids = MCOIndexSet.init(range: MCORangeMake(UInt64(partMessageIndex), UInt64(partOfMessages - 1)))
        
        let operation = appDelegate.imapSession.fetchMessagesByNumberOperation(withFolder: sourceFolder, requestKind: requestKind, numbers: uids)
        
        operation?.start({ [weak self] (error, fetchedMessages, vanishedMessages) in
            
            if error == nil
            {
                if let messages = fetchedMessages
                {
                    guard messages.count != 0 else {
                        
                        BFLog("parseMessages | self.allImapMessages.count ")
                        
                        self!.allPrecessDoneLabel.isHidden = false
                        self!.successfullMessagesLabel.isHidden = false
                        self!.failureMessagesLabel.isHidden = false
                        self!.skippedMessagesLabel.isHidden = false
                        
                        self!.successfullMessagesLabel.text = "Succesfull messages: \(self!.successfulCount)"
                        self!.failureMessagesLabel.text = "Failure messages: \(self!.allMessageCount - self!.successfulCount - self!.skippedCount)"
                        self!.skippedMessagesLabel.text = "Skipped messages: \(self!.skippedCount)"
                        
                        return
                    }
                    
                    self!.allMessageCount += messages.count
                    self?.globalMessageIndex = 0
                    self?.allImapMessages = messages as! [MCOIMAPMessage]
                    
                    BFLog("Current coping | uids: \(uids!)")
                    
                    self?.updateUIElements()
                    self?.parseMessages()
                }
            }
            else
            {
                BFLog("Error fetches messages: \(error!.localizedDescription)")
            }
        })
    }
    
    func loadPOPMessages() {
        
        
        
        
    }
    
    func parseMessages() {
		
        if !stopFlag {
            
            if serverType == "IMAP" {
                
				if globalMessageIndex < allImapMessages.count {
					
					let message = allImapMessages[globalMessageIndex]
                    messageUID = message.uid
					
                    BFLog("parseMessages | messageID: \(message.uid)")
					
					let key = appDelegate.currentServerName + "_" + sourceFolder + "_" + targetFolder.identifier!
                    successfullUdidsArray = (UserDefaults.standard.array(forKey: key) as? [UInt32]) ?? []
					
                    if !successfullUdidsArray!.contains(message.uid) {
                        
						BFLog("message \(message.uid) start inserting")
                        let parserMessageOperation = appDelegate.imapSession.fetchParsedMessageOperation(withFolder: sourceFolder, uid: message.uid)
                        parserMessageOperation?.start({ (error, local_parser) in
                            
                            if let pars = local_parser {
                                self.parser = pars
                                
                                if self.parser.attachments().count > 0 {
                                    
                                    let allAttachmentSize = self.getAllAttachmentSize()
                                    if allAttachmentSize > 20000000 {
                                        
                                        self.skippedCount += 1
                                        self.updateUIElements()
                                        self.parseMessages()
                                    } else {
                                        self.parseMesage()
                                    }
                                } else {
                                    self.parseMesage()
                                }
                                
                            } else {
                                
                                BFLog("fetchParsedMessage | parser is Nil")
                                BFLog("fetchParsedMessage | \(error!.localizedDescription)")
                                
                                self.updateUIElements()
                                self.parseMessages()
                            }
                        })
                    
                    } else {
                        
						BFLog("message \(message.uid) already inserting")
						
                        successfulCount += 1
                        updateUIElements()
                        
                        parseMessages()
                    }
					
				} else {
                    loadIMAPMessages()
				}
				
			} else {
				
				BFLog("parseMessages | Not IMAP ")
				
				if globalMessageIndex < appDelegate.allPopMessages.count {
					
					let message = appDelegate.allPopMessages[globalMessageIndex]
                    messageUID = message.index
					
					BFLog("message \(message.uid) start inserting")
					
					let arrayKey = appDelegate.currentServerName + "_" + sourceFolder + "_" + targetFolder.identifier!
					successfullUdidsArray = (UserDefaults.standard.array(forKey: arrayKey) as? [UInt32]) ?? []
					
                    if !successfullUdidsArray!.contains(message.index) {
                        
                        let operation = appDelegate.popSession.fetchMessageOperation(with: message.index)
                        operation?.start({ [weak self] (error, messageData) in
							
							if self == nil {return}
							
                            if error == nil {
                                
                                if let data = messageData {
                                    if let pars = MCOMessageParser(data: data) {
                                        self?.parser = pars
                                        
                                        if (self?.parser.attachments().count)! > 0 {
                                            
                                            let allAttachmentSize = self?.getAllAttachmentSize()
                                            if allAttachmentSize! > 20000000 {
                                                
                                                self?.skippedCount += 1
                                                self?.updateUIElements()
                                                self?.parseMessages()
                                            } else {
                                                self?.parseMesage()
                                            }
                                        } else {
                                            self?.parseMesage()
                                        }
                                        
                                    } else {
                                        
                                        BFLog("fetchMessageOperation | parser is Nil")
                                        BFLog("fetchMessageOperation | \(error!.localizedDescription)")
                                        
                                        self?.updateUIElements()
                                        self?.parseMessages()
                                    }
                                } else {
                                    
                                    BFLog("fetchMessageOperation | data is Nil")
                                    
                                    self?.updateUIElements()
                                    self?.parseMessages()
                                }
                                
                            } else {
								
                                BFLog(error!.localizedDescription)
                                
                                self?.updateUIElements()
                                self?.parseMessages()
                            }
                        })
                    
                    } else {
                        
                        BFLog("message \(message.uid) already inserting")
                        
                        successfulCount += 1
                        updateUIElements()
                        
                        parseMessages()
                    }
					
				} else {
					
					allPrecessDoneLabel.isHidden = false
					successfullMessagesLabel.isHidden = false
					failureMessagesLabel.isHidden = false
                    skippedMessagesLabel.isHidden = false
					
					successfullMessagesLabel.text = "Succesfull messages: \(successfulCount)"
					failureMessagesLabel.text = "Failure messages: \(allMessageCount - successfulCount - skippedCount)"
                    skippedMessagesLabel.text = "Skipped messages: \(skippedCount)"
				}
			}
		}
	}
	
    func parseMesage() {
		
		BFLog("parseMesageWithData | Start")
		
        if parser.header.from != nil && parser.header.from.mailbox != nil
        {
            mail.fromMail = parser.header.from.mailbox
        }
        else
        {
            BFLog("parseMesageWithData | fromMail Fail")
            mail.fromMail = ""
        }
        
        mail.toMail = appDelegate.gmail
        
        if parser.header.from != nil && parser.header.from.displayName != nil
        {
            mail.fromDisplayName = parser.header.from.displayName
        }
        else
        {
            BFLog("parseMesageWithData | displayName Fail")
            mail.fromDisplayName = ""
        }
        
        mail.toDisplayName = appDelegate.gmailFullName
        
        if parser.header.date != nil
        {
            mail.date = parser.header.date
        }
        else
        {
            BFLog("parseMesageWithData | date Fail")
            mail.date = Date()
        }
        
        if let body = parser.plainTextBodyRendering()
        {
            mail.body = body
        }
        else
        {
            BFLog("parseMesageWithData | body Fail")
            mail.body = ""
        }
        
        if let subject = parser.header.extractedSubject()
        {
            mail.subject = subject
        }
        else
        {
            BFLog("parseMesageWithData | subject Fail")
            mail.subject = "no subject"
        }
        
        if action == .Move {
            messageUIDLabel.text = "Moving message \"\(messageUID)\""
            messageSubjectLabel.text = "Subject: \"\(mail.subject)\""
        } else {
            messageUIDLabel.text = "Copying message \"\(messageUID)\""
            messageSubjectLabel.text = "Subject: \"\(mail.subject)\""
        }
        
        // if attachment exist
        if parser.attachments().count > 0 || parser.htmlInlineAttachments().count > 0
        {
            getMessageAttachment()
        }
        else
        {
            mail.attachment = []
            insertMessages()
        }
    }
	
    func getMessageAttachment()
	{
		BFLog("getMessageAttachment | Start")
		
        var attachmentArray = [String]()
        var attachmentCount = parser.attachments().count + parser.htmlInlineAttachments().count
        
        for i in 0 ..< parser.htmlInlineAttachments().count
		{
			if let attachment = parser.htmlInlineAttachments()[i] as? MCOAttachment
			{
				parseAttachment(attachment: attachment, attachmentCount: &attachmentCount, attachmentArray: &attachmentArray)
			}
        }
        
		BFLog("getMessageAttachment | attachment count: \(attachmentCount)")
        
        for i in 0 ..< parser.attachments().count
		{
            if let attachment = parser.attachments()[i] as? MCOAttachment
			{
				parseAttachment(attachment: attachment, attachmentCount: &attachmentCount, attachmentArray: &attachmentArray)
			}
        }
		
		BFLog("getMessageAttachment | End")
    }
    
    func parseAttachment(attachment: MCOAttachment, attachmentCount: inout Int, attachmentArray: inout [String]) {
		
		BFLog("parseAttachment | Start")
        
        var content = "\r\n--project\r\n"
        
        if attachment.filename != nil {
            
            content += "Content-Type: \(attachment.mimeType!); charset=\"UTF-8\"\r\n"
            content += "Content-Disposition: attachment; filename=\(attachment.filename!)\r\n"
            
        } else {
            content += "Content-Type: \(attachment.mimeType!)\r\n"
        }
        
		var base64String: String? = nil
		
		if let aData = attachment.data
		{
			// image data
			if attachment.mimeType == "image/png"
			{
				if let image = UIImage(data: aData)
				{
					let pngData = UIImagePNGRepresentation(image)
					base64String = GTLREncodeBase64(pngData)!
				}
			}
			else if attachment.mimeType == "image/jpeg"
			{
				if let image = UIImage(data: aData)
				{
					let jpegData = UIImageJPEGRepresentation(image, 1)
					base64String = GTLREncodeBase64(jpegData)!
				}
			}
			else
			{
				base64String = GTLREncodeBase64(aData)!
			}
		}
		
		if let tempStr = base64String
		{
			content += "Content-Transfer-Encoding: base64\r\n"
			content += tempStr + "\r\n"
			
			attachmentArray.append(content)
		}
		else
		{
			BFLog("parseAttachment | data is nil")
		}
		
		attachmentCount -= 1
		
        if attachmentCount == 0
		{
            mail.attachment = attachmentArray
            insertMessages()
        }
    }
    
    func insertMessages() {
		
		BFLog("insertMessages \(messageUID) | Start")
		
        let gmailMessage = GTLRGmail_Message()
        gmailMessage.labelIds = [targetFolder.identifier!, "UNREAD"]
		gmailMessage.internalDate = mail.date.timeIntervalSince1970 as NSNumber
		
        let upload = GTLRUploadParameters(data: self.getFormattedRawMessage(parser: parser, mail: self.mail), mimeType: "message/rfc822")
        
        //BFLog("upload: \(upload)")
        
        let query = GTLRGmailQuery_UsersMessagesInsert.query(withObject: gmailMessage, userId: "me", uploadParameters: upload)
		query.internalDateSource = "dateHeader"
		
        appDelegate.service.executeQuery(query) { [weak self] (ticket, some, error) in
			
			if self == nil {return}
			
            if error != nil {
                
				BFLog("message \(self!.messageUID) not insert")
				BFLog(error!.localizedDescription)
                
                if self?.failure == .Retry {
					
                    if self?.retryAndSkipCount ?? 0 > 0 {
                        
                        self?.retryAndSkipCount -= 1
                        self?.insertMessages()
                        return
                    
                    } else {
                        
                        self?.retryAndSkipCount = 3
                        self?.updateUIElements()
                        self?.parseMessages()
                        return
                    }
                
                } else if self?.failure == .Skip {
                    
                    self?.updateUIElements()
                    self?.parseMessages()
                    return
                
                } else if self?.failure == .Ask {
                    
                    let alertController = UIAlertController(title: "Error", message: error!.localizedDescription, preferredStyle: .alert)
                    
                    let skipAction = UIAlertAction(title: "Skip", style: .default, handler: { (skip) in
                        
                        self?.updateUIElements()
                        self?.parseMessages()
                        return
                    })
                    let stopAaction = UIAlertAction(title: "Stop", style: .default, handler: { (retry) in
                        
                        self?.globalMessageIndex = (self?.allImapMessages.count)!
                        _ = self?.navigationController?.popViewController(animated: true)
                        return
                    })
                    
                    alertController.addAction(skipAction)
                    alertController.addAction(stopAaction)
                    
                    self?.present(alertController, animated: true, completion: nil)
                    return
                }
            }
            
			BFLog("message \(self!.messageUID) insert successfull")
            
            // save messages 
            self?.successfullUdidsArray!.append(self!.messageUID)
			
			guard let sName = self?.appDelegate.currentServerName, let sFold = self?.sourceFolder, let target = self?.targetFolder.identifier else {
				return
			}
			
			let key = sName + "_" + sFold + "_" + target
			UserDefaults.standard.set( self?.successfullUdidsArray, forKey: key)
			UserDefaults.standard.set(key, forKey: "k_LastKey")
			
            self?.successfulCount += 1
            self?.updateUIElements()
            
            if self?.action == .Move {
                self?.deleteMessageWithUID(messageUID: self!.messageUID)
            } else {
                self?.parseMessages()
            }
        }
    }
    
    func deleteMessageWithUID(messageUID: UInt32) {
		
		if stopFlag {
			return
		}
		
		BFLog("deleteMessageWithUID ID: \(messageUID) | Start")
		
        if serverType == "IMAP" {
        
            let deleteFlag:MCOMessageFlag = [.deleted]
            let requestKindSet = MCOIMAPStoreFlagsRequestKind.set
        
            let storeOperation = appDelegate.imapSession.storeFlagsOperation(withFolder: sourceFolder, uids: MCOIndexSet.init(index: UInt64(messageUID)), kind: requestKindSet, flags: deleteFlag)
            storeOperation?.start({ [weak self] (error) in
				
				if self == nil {return}
				
                if error != nil {
                
                    BFLog(error!.localizedDescription)
                    return
                
                } else {
                
                    let deleteOperation = self?.appDelegate.imapSession.expungeOperation(self?.sourceFolder)
                    deleteOperation?.start({ (error) in
                    
                        if error != nil {
                            BFLog(error!.localizedDescription)
                        } else {
                        
							BFLog("delete was successful")
                            self?.parseMessages()
                        }
                    })
                
                }
            })
        
        } else {
            
            let deleteOperation = appDelegate.popSession.deleteMessagesOperation(with: MCOIndexSet.init(index: UInt64(messageUID)))
            deleteOperation?.start({ [weak self] (error) in
                if self == nil {return}
				
                if error != nil {
                    
                    BFLog(error!.localizedDescription)
                
                } else {
                    
					BFLog("delete was successful")
                    self?.parseMessages()
                }
            })
        }
    }
    
    func updateUIElements() {
		
		BFLog("updateUIElements | Start")
		
        globalMessageIndex += 1
        var percent = CGFloat()
        
        DispatchQueue.main.async {
            
            if self.serverType == "IMAP" {
                percent = (CGFloat(self.globalMessageIndex * 100) / CGFloat(self.allImapMessages.count)) / 100
                self.currentMessageLabel.text = "\(self.globalMessageIndex + self.partMessageIndex - self.partOfMessages) out of \(self.partMessageIndex)"

            } else {
                percent = (CGFloat(self.globalMessageIndex * 100) / CGFloat(self.appDelegate.allPopMessages.count)) / 100
                self.currentMessageLabel.text = "\(self.globalMessageIndex) out of \(self.appDelegate.allPopMessages.count)"
            }
            
            self.ldProgressView.progress = CGFloat(percent)
        }
    }
    
    func getAllAttachmentSize() -> Int {
        
        var attachmentSize: Int {
        
            var count = 0
            
            for attachment in parser.attachments() {
                count += (attachment as! MCOAttachment).data.count
            }
            
            return count
        }
        
        return attachmentSize
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
		BFLog("\(self.description) didReceiveMemoryWarning !!!!!!!!!!!!")
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
