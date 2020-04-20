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
    // local addr, port
    var localHost: NWEndpoint.Host?
    var localPort: NWEndpoint.Port? // not used, but here for completion
    
    // remote addr, port
    var remoteHost: NWEndpoint.Host?
    var remotePort: NWEndpoint.Port?
    
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
    
    public enum EndpointLocation {
        case local
        case remote
    }
    
    
    // if the status is set to "ready", the closure is able to be called
    var statusReady: (() throws -> Void)?
    var status: String = "unknown" {
        didSet {
            if status == "ready" {
                do {
                    try statusReady?()
                }
                catch let error {
                    print("status ready closure error: \(error)")
                }
            } // if status ready
        } // didSet
    } // status
    
    
    // not expecting to receive multi-message data
    // each time newData is set, the closure will execute anywhere it is called, able to access the data
    var newDataReceived: ((Data?) -> Void)?
    var newData: Data? {
        didSet {
            newDataReceived?(newData)
        }
    }
    
    
    // Get the local port opened to send
    // Return nil if no hostPort connection found
    func getHostPort(endpoint: EndpointLocation) -> (NWEndpoint.Host, NWEndpoint.Port)? {
        
        let endpointLocation: NWEndpoint?
        
        switch endpoint {
        case .local:
            endpointLocation = self.conn.currentPath?.localEndpoint
        case .remote:
            endpointLocation = self.conn.currentPath?.remoteEndpoint
        }
        
        // safely unwrap
        if let unwrappedEndpoint = endpointLocation {
            switch unwrappedEndpoint {
            case .hostPort(let host, let port):
                return (host, port)
            default:
                return nil
            }
        } else {
            return nil
        }
    } // Connection.getHostPort()
    
    
    // handles the receiving from tcp conn with light
    func receiveRecursively() -> Void {
        self.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, error) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            
            
            if error != nil {
                var host = "Unknown"
                if let unwrappedHost = self.remoteHost {
                    host = String(reflecting: unwrappedHost)
                }
                print("Conn receive error: \(host):  \(String(reflecting: error))")
                return
                
            } else {
                self.newData = data
                self.receiveRecursively()
            }
        } // conn.receive closure
    } // Connection.receiveRecursively()
    
    
    // separated so that init overrides don't need to include all this again
    func stateUpdateHandler() {
        
        var host = "Unknown IP"
        var port = "Unknown Port"
        
        if let unwrappedHost = self.remoteHost {
            host = String(reflecting: unwrappedHost)
        }
        if let unwrappedPort = self.remotePort {
            port = String(reflecting: unwrappedPort)
        }
        
        self.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.status = "setup"
            case .preparing:
                self.status = "preparing"
            case .ready:
                self.status = "ready"
                print("\(host): \(port) ready")
            case .waiting(let error):
                self.status = "waiting"
                print("\(host): \(port) waiting with error: \(String(reflecting: error))")
            case .failed(let error):
                self.status = "failed"
                print("\(host): \(port), connection failed with error: \(String(reflecting: error))")
            case .cancelled:
                self.status = "cancelled"
                print("\(host): \(port) connection cancelled")
            @unknown default:
                // recommended in case of future changes
                self.status = "unknown"
                print("Unknown status for \(host): \(port)")
            } // switch
        }
    } // stateUpdateHandler()
    
    
    // init new connection
    init(host: NWEndpoint.Host, port: NWEndpoint.Port, serialQueueLabel: String, connType: NWParameters, receiveLoop: Bool) {
        
        self.remoteHost = host
        self.remotePort = port
        
        // label the queue
        self.serialQueue = DispatchQueue(label: serialQueueLabel)
        
         // create initial connection
        self.conn = NWConnection(host: host, port: port, using: connType)
        
        // start connection
        self.conn.start(queue: self.serialQueue)
        
        // start state update handler
        self.stateUpdateHandler()
        
        // once connection is ready, save local host and port
        self.statusReady = {
            // used for establishing music mode tcp connections so code to find local port is cleaner
            let localHostPort = self.getHostPort(endpoint: .local)
            if let localHostPort = localHostPort {
                self.localHost = localHostPort.0
                self.localPort = localHostPort.1
            } else {
                print("Can't establish local host and port")
            }
            
            // actively receive messages received and set up new receiver
            if receiveLoop == true {
                self.receiveRecursively()
            }
            
        }
        
    } // Connection.init()
    
    
    // init with existing connection
    init(existingConn: NWConnection, existingQueue: DispatchQueue, remoteHost: NWEndpoint.Host, remotePort: NWEndpoint.Port, receiveLoop: Bool) {
        
        // for identification purposes
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        
        // save reference to the existing queue
        self.serialQueue = existingQueue
        
        // save reference to the existing connection
        self.conn = existingConn
        
        // start connection
        self.conn.start(queue: self.serialQueue)
        
        // start state update handler
        self.stateUpdateHandler()
        
        // once connection is ready, save local host and port
        self.statusReady = {
            // not required but for completeness
            let localHostPort = self.getHostPort(endpoint: .local)
            if let localHostPort = localHostPort {
                self.localHost = localHostPort.0
                self.localPort = localHostPort.1
            } else {
                print("Can't establish local host and port")
            }
            
            // actively receive messages received and set up new receiver
            if receiveLoop == true {
                self.receiveRecursively()
            }
            
        }
        

        
    }
    
    
    
    
} // class Connection
