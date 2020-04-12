//
//  classController.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/10.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network


/*
    FUNCTIONS
     - Discover()
     - turnOn()
     - turnOff()
     - setScene() - Does everything below but in one function
     - changeRGB()
     - changeHSV()
     - changeTemp
     - changeBright
 */



public class Controller {
    // aliases easier to read
    private typealias Property = String
    private typealias Value = String
    
    public typealias Alias = String
    public typealias ID = String
    
    // Stores all discovered lights as [idSerial : Data]
    public var lights: [String : Light] = [:]
    public var alias: [Alias : ID] = [:]
    
    // search addr, port
    private static let multicastHost: NWEndpoint.Host = "239.255.255.250"
    private static let multicastPort: NWEndpoint.Port = 1982
    
    // search message
    private static let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
    private static let searchBytes = searchMsg.data(using: .utf8)
    
    
    private let udpQueue = DispatchQueue(label: "udpQueue")
    let controlQueue = DispatchQueue(label: "Controller Queue", attributes: .concurrent)
    private let dispatchGroup = DispatchGroup()
    
    
    public enum DiscoveryWait {
        case lightCount(Int)
        case timeoutSeconds(Int)
        
        private func integer() -> Int {
            switch self {
            case .lightCount(let count):
                return count
            case .timeoutSeconds(let seconds):
                return seconds
            }
        }
    }
    
    private var waitMode = DiscoveryWait.timeoutSeconds(2)
    
    
    
    // parse string data to store light data
    private func parseData(Decoded decoded: String) -> [Property:Value] {
        // dictionary of all properties cleaned and separated
        var propertyDict: [Property:Value] = [:]
        
        // separate message string into separate lines
        var propertyList: [String] =
            decoded.components(separatedBy: "\r\n")
        
        // remove HTTP header
        // remove empty element at end that the final "\r\n" creates
        propertyList.removeFirst()
        propertyList.removeLast()
        
        // marker that indicates ip and port in array
        let addressMarker: String = "Location: yeelight://"
        
        // if find address marker, remove marker and separate ip and port
        // into own individual key value pairs.
        // Otherwise, create key value pair for each property
        for i in propertyList {
            if i.contains(addressMarker) {
                let ipPortString: String = i.replacingOccurrences(of: addressMarker, with: "")
                let ipPort: [String] = ipPortString.components(separatedBy: ":")
                propertyDict["ip"] = ipPort[0]
                propertyDict["port"] = ipPort[1]
                
            } else {
                let keyValue: [String] =
                    i.components(separatedBy: ": ")
                let key: Property = keyValue[0]
                let value: Value = keyValue[1]
                
                // add key value pair to dictionary
                propertyDict[key] = value
            }
        }
        // possible to return empty
        return propertyDict
    } // Controller.parseData()
    
    
    // convert strings to data types and create struct
    private func createLight(_ property: [Property:Value]) throws -> Light {
            
            guard
                let ip = property["ip"],
                let port = property["port"],
                let id = property["id"],
                let power = property["power"],
                let brightness = property["bright"],
                let colorMode = property["color_mode"],
                let colorTemp = property["ct"],
                let rgb = property["rgb"],
                let hue = property["hue"],
                let sat = property["sat"],
                let name = property["name"],
                let model = property["model"],
                let support = property["support"]
                else {
                    throw DiscoveryError.propertyKey
            }
            
            // create class Light instance
            let light = try Light(id, ip, port, power, colorMode, brightness, colorTemp, rgb, hue, sat, name, model, support)
            
            return light
    } // Controller.createLight()
    
    
    // handles replies received from lights with listener
    private func udpDecodeHandler(_ data: Data?) {
            
        // is there data?
        guard let unwrappedData: Data = data else {
            print("Empty data from UDP message received")
            return
        }
        
        // decode data to String
        guard let decoded: String = String(data: unwrappedData, encoding: .utf8) else {
            print("UDP data message received cannot be decoded")
            return
        }
        
        // separate properties into dictionary to inspect
        let properties: [Property:Value] = self.parseData(Decoded: decoded)
        
        // create tcp connection to each light and save that connection and data
        // print errors identified
        
        // save the light to class dictionary
        
        do {
            guard let id = properties["id"] else {
                throw DiscoveryError.idValue
            }
            
            if self.lights[id] == nil {
                // use a queue in case Listner's connections are asynchronous and try to access dictionary at the same time
                try self.controlQueue.sync {
                    // Add new light to dictionary if doesn't already exist
                    self.lights[id] = try self.createLight(properties)
                    
                    if case DiscoveryWait.lightCount(let expectedCount) = waitMode {
                        if self.lights.count >= expectedCount {
                            //cancel listener and connection
                            // run dispatch work item and add all together?
                            // put this in a separate function?
                        }
                    }
                }
                
            }
            
        }
        catch let error {
            print(error)
        }
        //throw DiscoveryError.idValue
        
        
    } // Controller.udpReplyHandler()
    
    
    // Listen for reply from multicast
    private func udpListener(_ port: NWEndpoint.Port) {
        
        if let listener = try? NWListener(using: .udp, on: port) {
            listener.newConnectionHandler = { (udpNewConn) in
                // create connection, listen to reply and create lights from data received
                
                udpNewConn.start(queue: self.udpQueue)
                
                udpNewConn.receiveMessage { (data, _, _, error) in
                    if error != nil {
                        print(error as Any)
                    }
                    
                    if let data = data {
                        
                        self.udpDecodeHandler(data)
                    }
                    
                } // receiveMessage
                
                
                // No use for discovery socket anymore
                // do I need to sleep the thread before cancelling?
                ///////////////////////
                // udpNewConn.cancel()
                
            }
            listener.start(queue: self.udpQueue)
            
            // at some point, cancel the listener after X seconds
        }
    } // Controller.udpListener()
    
    
    // Get the local port opened to send
    // Return nil if no hostPort connection found
    private func getLocalPort(fromConnection conn: NWConnection) -> NWEndpoint.Port? {
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
    } // Controller.getLocalPort()
    
    
    
    
    /// asynchronously wait during execution to be timed out.  Upon completion, asynchronously execute the code in the closure.
    private func timeout(seconds: UInt32, closureFunc:@escaping ()->()) {
        self.controlQueue.async {
            sleep(seconds)
            closureFunc()
        }
    }
    
    
    
    
    
    
    
    
    
    // =====================================================================
    // FUNCTIONS ===========================================================
    // =====================================================================
    
    
    public func discover(wait: DiscoveryWait) {
        
        self.waitMode = wait
        
        // clear all existing lights
        self.lights.removeAll(keepingCapacity: true)
        
        // Setup UDP connection
        let udpSearchConn = NWConnection(host: Controller.multicastHost, port: Controller.multicastPort, using: .udp)
        
        
        let startConnection = DispatchWorkItem {
            // Start the connection
            udpSearchConn.start(queue: self.udpQueue)
        }
        
        
        let searchBlock = DispatchWorkItem {
            // Get local port.  If returns nil, notify then end discovery
            guard let localPort = self.getLocalPort(fromConnection: udpSearchConn) else {
                print("Couldn't find local port")
                return
            }
            
            // Can probably go to the class variables
            // Setup procedure to do when search message is sent
            let sendComplete = NWConnection.SendCompletion.contentProcessed { (error) in
                if error != nil {
                    print(error as Any)
                    return
                }
            } // sendComplete
            
            // Send search message
            udpSearchConn.send(content: Controller.searchBytes, completion: sendComplete)
            
            // Listen for light replies and create a new light tcp connection
            self.udpListener(localPort)
        }
        

        
        udpSearchConn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .ready:
                startConnection.notify(queue: self.controlQueue, execute: searchBlock)
            case .waiting:
                print("No connection available")
            case .failed(let error):
                print("UDP connection returned error: \(error)")
                startConnection.cancel()
            case .cancelled:
                print("UDP connection: cancelled")
                startConnection.cancel()
            default:
                return
            }
        }
        
        
        self.controlQueue.async(execute: startConnection)
        
        
        
        //let waitResult = self.dispatchGroup.wait(timeout: .now() + 1)
        
        
        
        
       /*
         self.timeout(seconds: 1) {
         // start connection attempt timeout - do I need this?  Test it.
         if udpSearchConn.state != .ready {
         udpSearchConn.cancel()
         self.dispatchGroup.leave()
         }
         }
         
         
         if waitResult == .timedOut {
         
         }
         
         if udpSearchConn.state != .ready {
         udpSearchConn.cancel()
         self.dispatchGroup.leave()
         }
         
         
        */
        
        
        
        
        
        
    } // Controller.discover()
    
    
    
} // class Controller

