//
//  WebhookTests.swift
//  Jared
//
//  Created by Zeke Snider on 2/2/19.
//  Copyright © 2019 Zeke Snider. All rights reserved.
//

import XCTest
import JaredFramework

class WebhookTests: XCTestCase {
    let WEBHOOK_TEST_URL = "https://github.com/zekesnider/jaredwebhook"
    let WEBHOOK_TEST_URL_TWO = "https://twitter.com/zekesnider/jaredwebhook"
    let MESSAGE_SERIALIZED = "{\"body\":{\"message\":\"hello there jared\"},\"recipient\":{\"handle\":\"jared@email.com\",\"givenName\":\"jared\",\"isMe\":false},\"sender\":{\"handle\":\"zeke@email.com\",\"givenName\":\"zeke\",\"isMe\":true},\"date\":\"2017-05-17T22:57:21.000Z\"}"
    let SAMPLE_MESSAGE = Message(body: TextBody("hello there jared"), date: Date(timeIntervalSince1970: TimeInterval(1495061841)), sender: Person(givenName: "zeke", handle: "zeke@email.com", isMe: true), recipient: Person(givenName: "jared", handle: "jared@email.com", isMe: false))
    
    var config: URLSessionConfiguration!
    
    override func setUp() {
        config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
    }

    override func tearDown() {
        URLProtocolMock.matchedDataURLs = []
    }

    func testvalidURLsCall() {
        // set up first call to webhook with one url
        let url = URL(string: WEBHOOK_TEST_URL)
        URLProtocolMock.testURLs = [url: Data(MESSAGE_SERIALIZED.utf8)]
        let webhookManager = WebHookManager(webhooks: [WEBHOOK_TEST_URL], session: config)
        
        webhookManager.notify(message: SAMPLE_MESSAGE)
        
        // Not ideal but didn't want to plumb in a callback yet because
        // it's not used in the impl.
        sleep(2)
        
        XCTAssert(URLProtocolMock.matchedDataURLs.count == 1, "Webhooks were requested")
        
        // setup for second call which adds another url to the webhook
        // list
        webhookManager.updateHooks(to: [WEBHOOK_TEST_URL, WEBHOOK_TEST_URL_TWO])
        let urlTwo = URL(string: WEBHOOK_TEST_URL_TWO)
        URLProtocolMock.testURLs = [
            url: Data(MESSAGE_SERIALIZED.utf8),
            urlTwo: Data(MESSAGE_SERIALIZED.utf8)
        ]
        URLProtocolMock.matchedDataURLs = []
        
        webhookManager.notify(message: SAMPLE_MESSAGE)
        
        sleep(2)
        
        XCTAssert(URLProtocolMock.matchedDataURLs.count == 2, "Webhooks were requested after configuration change")
    }
}
