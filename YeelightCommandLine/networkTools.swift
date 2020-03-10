//
//  networkTools.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/10.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network







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
}


func udpReplyHandler(newConn conn: NWConnection) -> Data? {
    // starts connection
    // receives data from connection
    // if complete, cancels the connection
    // returns data.  Returns nil if error.
    var receivedData: Data
    var returnData: Bool = false
    
    conn.start(queue: connQueue)
    
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: { (data, _, isComplete, _) in
        // data, defaultMessage, isComplete, errors (enum dns posix tcl)
        
        if let data: Data = data, !data.isEmpty {
            receivedData = data
            returnData = true
        }
        
        if isComplete == true {
            // Won't need UDP connection with the light anymore
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


//print(String(data: data, encoding: .utf8)!)
/*
procQueue.async(qos: .userInitiated) {
    semaphore.wait()
 
    
    semaphore.signal()
}
*/



// Listen for reply from multicast
func udpListenReply(onPort port: NWEndpoint.Port) -> [Data] {
    var allReplies: [Data] = []
    
    if let listener = try? NWListener(using: NWParameters.udp, on: port) {
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


