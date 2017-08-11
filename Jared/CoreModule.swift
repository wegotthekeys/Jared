//
//  CoreModule.swift
//  Jared 3.0 - Swiftified
//
//  Created by Zeke Snider on 4/3/16.
//  Copyright © 2016 Zeke Snider. All rights reserved.
//

import Foundation
import Cocoa
import JaredFramework
import AddressBook
import Contacts

public func NSLocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, tableName: "CoreStrings", comment: "")
}


class CoreModule: RoutingModule {
    var description: String = NSLocalizedString("CoreDescription")
    var routes: [Route] = []
    let MAXIMUM_CONCURRENT_SENDS = 3
    var currentSends: [String: Int] = [:]
    
    let mystring = NSLocalizedString("hello", tableName: "CoreStrings", value: "", comment: "")
    
    required public init() {
        let ping = Route(name:"/ping", comparisons: [.startsWith: ["/ping"]], call: self.pingCall, description: NSLocalizedString("pingDescription"))
        
        let thankYou = Route(name:"Thank You", comparisons: [.startsWith: [NSLocalizedString("ThanksJaredCommand")]], call: self.thanksJared, description: NSLocalizedString("ThanksJaredResponse"))
        
        let version = Route(name: "/version", comparisons: [.startsWith: ["/version"]], call: self.getVersion, description: "versionDescription")
        
        let whoami = Route(name: "/whoami", comparisons: [.startsWith: ["/whoami"]], call: self.getWho, description: "Get your name")
        
        let send = Route(name: "/send", comparisons: [.startsWith: ["/send"]], call: self.sendRepeat, description: NSLocalizedString("sendDescription"),parameterSyntax: NSLocalizedString("sendSyntax"))
        
        let name = Route(name: "/name", comparisons: [.startsWith: ["/name"]], call: self.changeName, description: "Change what Jared calls you", parameterSyntax: "/name,[your preferred name]")

        routes = [ping, thankYou, version, send, whoami, name]
    }
    
    
    func pingCall(_ message:String, myRoom: Room) -> Void {
        SendText(NSLocalizedString("PongResponse"), toRoom: myRoom)
    }
    
    func getWho(_ message:String, myRoom: Room) -> Void {
        SendText("Your name is \(myRoom.buddyName!).", toRoom: myRoom)
    }
    
    func thanksJared(_ message:String, myRoom: Room) -> Void {
        SendText(NSLocalizedString("WelcomeResponse"), toRoom: myRoom)
    }
    
    func getVersion(_ message:String, myRoom: Room) -> Void {
        SendText(NSLocalizedString("versionResponse"), toRoom: myRoom)
    }
    
    var guessMin: Int? = 0
    
    func sendRepeat(_ message:String, myRoom: Room) -> Void {
        let parameters = message.components(separatedBy: ",")
        
        //Validating and parsing arguments
        guard let repeatNum: Int = Int(parameters[1]) else {
            SendText("Wrong argument. The first argument must be the number of message you wish to send", toRoom: myRoom)
            return
        }
        
        guard let delay = Int(parameters[2]) else {
            SendText("Wrong argument. The second argument must be the delay of the messages you wish to send", toRoom: myRoom)
            return
        }
        
        guard var textToSend = parameters[safe: 3] else {
            SendText("Wrong arguments. The third argument must be the message you wish to send.", toRoom: myRoom)
            return
        }
        
        guard myRoom.buddyHandle != nil else {
            SendText("You must have a proper handle.", toRoom: myRoom)
            return
        }
        
        guard (currentSends[myRoom.buddyHandle!] ?? 0) < MAXIMUM_CONCURRENT_SENDS else {
            SendText("You can only have \(MAXIMUM_CONCURRENT_SENDS) send operations going at once.", toRoom: myRoom)
            return
        }
        
        //Increment the concurrent send counter for this user
        currentSends[myRoom.buddyHandle!] = currentSends[myRoom.buddyHandle!] ?? 0 + 1
        
        //If there are commas in the message, take the whole message
        if parameters.count > 3 {
            textToSend = parameters[2...(parameters.count - 1)].joined(separator: ",")
        }
        
        //Go through the repeat loop...
        for _ in 1...repeatNum {
            SendText(textToSend, toRoom: myRoom)
            Thread.sleep(forTimeInterval: Double(delay))
        }
        
        //Decrement the concurrent send counter for this user
        currentSends[myRoom.buddyHandle!] = (currentSends[myRoom.buddyHandle!] ?? 0) - 1
        
    }
    
    func changeName(_ myMessage: String, forRoom: Room) {
        let parsedMessage = myMessage.components(separatedBy: ",")
        if (parsedMessage.count == 1) {
            SendText("Wrong arguments.", toRoom: forRoom)
            return
        }
        let store = CNContactStore()
        
        //Attempt to open the address book
        if let book = ABAddressBook.shared() {
            let emailSearchElement = ABPerson.searchElement(forProperty: kABEmailProperty, label: nil, key: nil, value: forRoom.buddyHandle, comparison: ABSearchComparison(kABEqualCaseInsensitive.rawValue))
            let phoneSearchElement = ABPerson.searchElement(forProperty: kABPhoneProperty, label: nil, key: nil, value: forRoom.buddyHandle, comparison: ABSearchComparison(kABEqualCaseInsensitive.rawValue))
            let bothSearchElement = ABSearchElement(forConjunction: ABSearchConjunction(kABSearchOr.rawValue), children: [emailSearchElement!, phoneSearchElement!])
            let peopleFound = book.records(matching: bothSearchElement)
            
            //We need to create the contact
            if (peopleFound?.count == 0) {
                // Creating a new contact
                let newContact = CNMutableContact()
                newContact.givenName = parsedMessage[1]
                newContact.note = "Created By Jared.app"
                
                //If it contains an at, add the handle as email, otherwise add it as phone
                if (forRoom.buddyHandle!.contains("@")) {
                    let homeEmail = CNLabeledValue(label: CNLabelHome, value: (forRoom.buddyHandle ?? "") as NSString)
                    newContact.emailAddresses = [homeEmail]
                }
                else {
                    let iPhonePhone = CNLabeledValue(label: "iPhone", value: CNPhoneNumber(stringValue:forRoom.buddyHandle ?? ""))
                    newContact.phoneNumbers = [iPhonePhone]
                }
            
                let saveRequest = CNSaveRequest()
                saveRequest.add(newContact, toContainerWithIdentifier:nil)
                do {
                    try store.execute(saveRequest)
                } catch {
                    SendText("There was an error saving your contact..", toRoom: forRoom)
                    return
                }
                
                SendText("Ok, I'll call you \(parsedMessage[1]) from now on.", toRoom: forRoom)
                
            }
                //The contact already exists, modify the value
            else {
                let myPerson = peopleFound?[0] as! ABRecord
                ABRecordSetValue(myPerson, kABFirstNameProperty as CFString, parsedMessage[1] as CFTypeRef)
                
                book.save()
                SendText("Ok, I'll call you \(parsedMessage[1]) from now on.", toRoom: forRoom)
            }
        }
            //If we do not have permission to access contacts
        else {
            SendText("Sorry, I do not have access to contacts.", toRoom: forRoom)
        }
    }
}
