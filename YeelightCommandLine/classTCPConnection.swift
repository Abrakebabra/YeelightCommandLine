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
    
    
    init(TargetIP ip: String, TargetPort port: String, ID id: String) throws {
        
        guard let NWPort: NWEndpoint.Port = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed
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
                print("\(ip), \(id) ready")
            case .waiting:
                self.status = "waiting"
                print("\(ip), \(id) waiting")
            case .failed:
                self.status = "failed"
                print("\(ip), \(id) tcp connection failed")
            case .cancelled:
                self.status = "cancelled"
                print("\(ip), \(id) tcp connection cancelled")
            default:
                self.status = "unknown"
                print("Unknown error for \(ip), \(id)")
            }
        }
        
        self.conn.start(queue: connQueue)
        
    }
    
    
    // Send a command to the light
    func command(CommandString commandString: String) {
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


