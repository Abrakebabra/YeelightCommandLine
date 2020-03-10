//
//  yeelight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/10.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network



/*
 
 struct light properties
 
 
 Light Class
 let DispatchQueue("Network Queue") (Or one for outgoing one for incoming?)
 let DispatchQueue("background/wait queue?")
 
 func discover()
 let multiHost
 let multiPort
 let byteMessage
 
 create UDP connection
 udpConnection state handler?
 start UDP connection - What if connection fails?  Error?
 setup send completion procedure - handle send error
 get local port - handle error
 setup replyListen function
 SEND
 Listen to replies and dump all data
 Sift through data, sort and create light instances?
  - How should I store the lights?
    - Dictionary of ID followed by data?
    - Light objects?
    -
 
 Perhaps discover network code in a separate class?
 
 */

public struct State {
    let ip: String  // var?  If re-discover lights?
    let port: Int  // var?  If re-discover lights?
    let idSerial: String
    
    let model: String
    let fw_ver: String
    
    var power: Bool
    var brightness: Int
    var colorMode: Int
    var colorTemp: Int
    var rgb: Int
    var hue: Int
    var sat: Int
    var name: String
}


public class Yeelight {
    public var lights: [String : State] = [:]
    
    // no init func yet
    
    public func discover() {
        let multicastHost: NWEndpoint.Host = "239.255.255.250"
        let multicastPort: NWEndpoint.Port = 1982
        let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
        let searchBytes = searchMsg.data(using: .utf8)
        
        // Setup UDP connection
        let udpConn = NWConnection(host: multicastHost, port: multicastPort, using: NWParameters.udp)
        
        func extractData() -> Void {
            // Handle the data extracted into 
        }
        
        
        // Setup procedure to do when search message is sent
        // get local port
        // listen for replies from lights on that port
        // dump data into array
        let sendSearchCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            if NWError == nil {
                if let localPort = getLocalPort(fromConnection: udpConn) {
                    let replyArray = udpListenReply(onPort: localPort)
                }
            }
            //if let NWError = NWError {
            //    print(NWError)
            //}
        }
        
        // Start the connection
        udpConn.start(queue: connQueue)
        
        
        
        
    }
    

    

    
    
}




// connection state handler
udpConnection.stateUpdateHandler = { (newState) in
    switch(newState) {
    case .setup:
        print("Setting up!")
    case .preparing:
        print("Preparing!")
    case .ready:
        print("Ready!")
    case .waiting:
        print("Waiting!")
    case .failed:
        print("Failed!")
    case .cancelled:
        print("Cancelled!")
    }
}


















udpConnection.send(content: searchBytes, completion: sendSearchCompletion)


testQueue.async(qos: .background) {
    udpConnection.cancel()
}

