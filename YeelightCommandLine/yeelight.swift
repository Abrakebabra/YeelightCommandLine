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
    let server: String
    let idSerial: String
    
    let model: String
    let fw_ver: String
    let support: String
    
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
        // enter expected number of lights to find?
        // or find them all, then prompt if it looks right
        
        let multicastHost: NWEndpoint.Host = "239.255.255.250"
        let multicastPort: NWEndpoint.Port = 1982
        let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
        let searchBytes = searchMsg.data(using: .utf8)
        
        // Setup UDP connection
        let udpConn = NWConnection(host: multicastHost, port: multicastPort, using: .udp)
        
        
        
    
        
        
        func parseData(Decoded decoded: String) {
            // parse the information received into struct
            let decoded = decoded
            let separatedProperties: [String] = decoded.components(separatedBy: "\r\n")
            var dictionaryProperties: [String: String] = [:]
            
            let addressMarker: String = "Location: yeelight://"
            
            for i in separatedProperties {
                
                if i.contains(addressMarker) {
                    let ipPort: String = i.replacingOccurrences(of: addressMarker, with: "")
                    // then handle it like the others
                } else {
                    // do this
                }
                
                
                let keyValue: [String] = i.components(separatedBy: ":")
                let key: String = keyValue[0]
                
                
                // split out \r\nLocation: yeelight://
            
        
        
        // reads data array and stores meaningful light information
        func extractData(Received array: [Data]) {
            // convert data into string
            // manipulate string into separate data properties
            let array: [Data] = array
            var decoded: [String] = []
            
            for i in array {
                if let i: String = String(data: i, encoding: .utf8) {
                    decoded.append(i)
                }
            }
            
            
        }
        
        
        // handles replies received from lights with listener
        func udpReplyHandler(newConn conn: NWConnection) -> Data? {
            // starts connection
            // receives data from connection
            // if complete, cancels the connection
            // returns data.  Returns nil if error.
            var receivedData: Data
            var returnData: Bool = false
            
            conn.start(queue: connQueue)
            
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: { (data, _, _, _) in
                // data, defaultMessage, isComplete, errors (enum dns posix tcl)
                
                if let data: Data = data, !data.isEmpty {
                    receivedData = data
                    returnData = true
                    // won't need the connection anymore
                    conn.cancel()
                }
                // Handle NW errors?
            })
            
            if returnData == true {
                return receivedData
            } else {
                return nil
            }
        }
        
        
        // Listen for reply from multicast
        func udpListenReply(onPort port: NWEndpoint.Port) -> [Data] {
            var allReplies: [Data] = []
            
            if let listener = try? NWListener(using: .udp, on: port) {
                listener.newConnectionHandler = { (newConn) in
                    let data = udpReplyHandler(newConn: newConn)
                    
                    if let data = data {
                        allReplies.append(data)
                    }
                }
                listener.start(queue: connQueue)
            }
            
            // If everything fails, will return empty array
            return allReplies
        }
        
        
        
        // Setup procedure to do when search message is sent
        let sendSearchCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            // get local port
            // listen for replies from lights on that port
            // dump data into array
            if NWError == nil {
                if let localPort = getLocalPort(fromConnection: udpConn) {
                    let dataArray: [Data] = udpListenReply(onPort: localPort)
                }
            }
            //if let NWError = NWError {
            //    print(NWError)
            //}
        }
        
        // Start the connection
        udpConn.start(queue: connQueue)
        
        
        // Send search message and handle replies
        udpConn.send(content: searchBytes, completion: sendSearchCompletion)
        
    }
    

}


