//
//  tcpConnection.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network

class TCPConnection {
    let ip: NWEndpoint.Host
    let port: NWEndpoint.Port
    let conn: NWConnection
    let id: String
    var status: String
    
    let complete = NWConnection.SendCompletion.contentProcessed { (_) in
        // no send completion instructions yet
    }
    
    init(TargetIP ip: String, TargetPort port: String, ID id: String)
        throws {
        
        guard let NWPort: NWEndpoint.Port = NWEndpoint.Port(port)
            else {
            throw DiscoveryError.tcpInitFailed("String to NWEndpoint.Port")
        }
        
        self.ip = NWEndpoint.Host(ip)
        self.port = NWPort
        self.conn = NWConnection.init(host: self.ip, port: self.port, using: .tcp)
        self.id = id
        self.status = "unknown"
        
        self.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.status = "setup"
            case .preparing:
                self.status = "preparing"
            case .ready:
                self.status = "ready"
                print("\(self.ip), \(self.id) ready")
            case .waiting:
                self.status = "waiting"
                print("\(self.ip), \(self.id) waiting")
            case .failed:
                self.status = "failed"
                print("\(self.ip), \(self.id) tcp connection failed")
            case .cancelled:
                self.status = "cancelled"
                print("\(self.ip), \(self.id) tcp connection cancelled")
            default:
                self.status = "unknown"
                print("Unknown error for \(self.ip), \(self.id)")
            }
        }
        
        self.conn.start(queue: connQueue)
        
    }
    
    
    // Send a command to the light
    func command(CommandString commandString: String) throws {
        
        
        
        guard let commandByte: Data = commandString.data(using: .utf8) else {
            throw CommandError.invalidString
        }
        
        
        self.conn.send(content: commandByte, completion: complete)
        
        self.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, _) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            print(data)
        }
        
        // takes in JSON string
        // sends that to a light
        // awaits for a reply
        // sort through various replies or errors from light
        // time out error too
        // return that reply to what called the function
        // throw errors
        
        // needs send completion
        // Do I handle things in send completion?
        
    }
    
}


