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





//print(String(data: data, encoding: .utf8)!)
/*
procQueue.async(qos: .userInitiated) {
    semaphore.wait()
 
    
    semaphore.signal()
}
*/

