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
    
    // Connection
    var conn: NWConnection
    
    var sendCompletion = NWConnection.SendCompletion.contentProcessed { (error) in
        if error != nil {
            print(error.debugDescription)
            return
        }
    } // sendCompletion
    
    // if true, will always have a recursive receiver
    var receiveLoop: Bool = false
    
    // if the status is set to "ready", the closure is able to be called
    var statusReady: (() -> Void)?
    var status: String = "unknown" {
        didSet {
            if status == "ready" {
                statusReady?()
            }
        }
    }
    
    // not expecting to receive multi-message data
    // each time newData is set, the closure will execute anywhere it is called, able to access the data
    var newDataReceived: ((Data?) -> Void)?
    var newData: Data? {
        didSet {
            newDataReceived?(newData)
        }
    }
    
    
    
    // handles the receiving from tcp conn with light
    private func receiveRecursively() -> Void {
        self.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, error) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            
            if self.receiveLoop == false {
                return
            }
            
            if error != nil {
                self.receiveLoop = false
                print("\(self.endpointHost):  \(error.debugDescription)")
                return
            }
            
            self.newData = data
            
            // recurse
            if self.receiveLoop == true {
                self.receiveRecursively()
            }
            
        } // conn.receive closure
    } // Light.receiveAndUpdateState()
    
    
    
    init(host: NWEndpoint.Host, port: NWEndpoint.Port, serialQueueLabel: String, connType: NWParameters, receiveLoop: Bool) {
        
        self.endpointHost = host
        self.endpointPort = port
        self.serialQueue = DispatchQueue(label: serialQueueLabel)
        
        // create initial connection
        self.conn = NWConnection(host: self.endpointHost, port: self.endpointPort, using: connType)
        
        // start connection
        self.conn.start(queue: self.serialQueue)
        
        self.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.status = "setup"
            case .preparing:
                self.status = "preparing"
            case .ready:
                self.status = "ready"
                print("\(self.endpointHost.debugDescription): \(self.endpointPort.debugDescription) ready")
            case .waiting(let error):
                self.status = "waiting"
                print("\(self.endpointHost.debugDescription): \(self.endpointPort.debugDescription) waiting with error: \(error.debugDescription)")
            case .failed(let error):
                self.status = "failed"
                print("\(self.endpointHost.debugDescription): \(self.endpointPort.debugDescription), connection failed with error: \(error.debugDescription)")
            case .cancelled:
                self.status = "cancelled"
                print("\(self.endpointHost.debugDescription): \(self.endpointPort.debugDescription) connection cancelled")
            @unknown default:
                // recommended in case of future changes
                self.status = "unknown"
                print("Unknown status for \(self.endpointHost.debugDescription)")
            } // switch
        } // stateUpdateHandler
        
        // actively receive messages received and set up new receiver
        if receiveLoop == true {
            self.receiveRecursively()
        }
        
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
    
} // class Connection
