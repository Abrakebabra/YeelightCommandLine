//
//  classConnection.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/04/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network



public class Connection {
    // search addr, port
    let endpointHost: NWEndpoint.Host
    let endpointPort: NWEndpoint.Port
    
    // dispatch management
    let serialQueue: DispatchQueue
    let dispatchGroup = DispatchGroup()
    
    // UDP Connection
    var conn: NWConnection
    
    var sendCompletion = NWConnection.SendCompletion.contentProcessed { (error) in
        if error != nil {
            print(error.debugDescription)
            return
        }
    } // sendCompletion
    
    
    
    init(host: NWEndpoint.Host, port: NWEndpoint.Port, serialQueueLabel: String, connType: NWParameters) {
        
        self.endpointHost = host
        self.endpointPort = port
        self.serialQueue = DispatchQueue(label: serialQueueLabel)
        
        // create initial connection
        self.conn = NWConnection(host: self.endpointHost, port: self.endpointPort, using: connType)
        
    } // Connection.init()
    
    
    // Get the local port opened to send
    // Return nil if no hostPort connection found
    func getLocalPort(fromConnection conn: NWConnection) -> NWEndpoint.Port? {
        if let localEndpoint: NWEndpoint = conn.currentPath?.localEndpoint {
            switch localEndpoint {
            case .hostPort(_, let port):
                return port
            default:
                return nil
            }
        } else {
            return nil
        }
    } // Connection.getLocalPort()
    
    
    // separate function for readability for use in different functions
    func receiver(_ conn: NWConnection, _ closure:@escaping (Data) -> Void) -> Void {
        
        conn.receiveMessage { (data, _, _, error) in
            if error != nil {
                print(error.debugDescription)
            }
            
            if let data = data {
                closure(data)
            }
        } // receiveMessage
    } // Connection.receiver()
    
} // class Connection
