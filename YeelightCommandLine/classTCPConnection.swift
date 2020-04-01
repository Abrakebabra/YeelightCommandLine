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
    let tcpDispatchGroup: DispatchGroup
    
    let complete = NWConnection.SendCompletion.contentProcessed { (NWError) in
        if NWError != nil {
            print(NWError as Any)
        }
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
        self.tcpDispatchGroup = DispatchGroup()
        
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
                print("\(self.ip), \(self.id) tcp connection failed.  Restarting.")
                self.conn.restart()
            case .cancelled:
                self.status = "cancelled"
                print("\(self.ip), \(self.id) tcp connection cancelled")
            default:
                self.status = "unknown"
                print("Unknown error for \(self.ip), \(self.id).  Restarting.")
                self.conn.restart()
            }
        }
        
        self.conn.start(queue: connQueue)
    } // init()
    
    
    // Send a command to the light
    func commandAndResponse(CommandString commandData: Data) throws -> [String] {
        // takes in JSON string
        // sends that to a light
        // awaits for a reply
        // sort through various replies or errors from light
        // time out error too
        // return that reply to what called the function
        // throw errors found in JSON reply from light
        
        var responseData: Data?
        
        self.conn.send(content: commandData, completion: complete)
        
        self.tcpDispatchGroup.enter()
        self.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, NWError) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            if NWError != nil {
                print(NWError as Any)
                self.tcpDispatchGroup.leave()
                return
                
            } else {
                responseData = data
                self.tcpDispatchGroup.leave()
            }
        }
        
        self.tcpDispatchGroup.wait()
        let reply = try jsonDecoder(Response: responseData)
        
        return reply
    } // commandAndResponse
}


