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

// ==========================================================================
// CONTENTS =================================================================
// ==========================================================================

// enum DiscoveryWait
// class UDPConnection
// class Controller


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



// ==========================================================================
// CLASS UDPCONNECTION ======================================================
// ==========================================================================



public class UDPConnection {
    // search addr, port
    private static let multicastHost: NWEndpoint.Host = "239.255.255.250"
    private static let multicastPort: NWEndpoint.Port = 1982
    
    // search message
    private static let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
    private static let searchBytes = searchMsg.data(using: .utf8)
    
    // dispatch management
    private let serialQueue = DispatchQueue(label: "Serial Queue")
    private let dispatchGroup = DispatchGroup()
    
    // UDP Connection
    private var searchConn: NWConnection
    
    private static var sendCompletion = NWConnection.SendCompletion.contentProcessed { (error) in
        if error != nil {
            print(error.debugDescription)
            return
        }
    } // udpSendCompletion
    
    
    
    init() {
        // create initial connection
        self.searchConn = NWConnection(host: UDPConnection.multicastHost, port: UDPConnection.multicastPort, using: .udp)
        
    } // UDPController.init()
    
    
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
    } // UDPConnection.getLocalPort()
    
    
    // separate function for readability in listener()
    private func receiver(_ conn: NWConnection, _ closure:@escaping (Data) -> Void) -> Void {
        
        conn.receiveMessage { (data, _, _, error) in
            if error != nil {
                print(error.debugDescription)
            }
            
            if let data = data {
                closure(data)
            }
        } // receiveMessage
    } // UDPConnection.receiver()
    
    
    // Listen for reply from multicast
    private func listener(on port: NWEndpoint.Port, wait mode: DiscoveryWait,  closure: @escaping ([Data]) -> Void) {
        
        let lightDispatch = DispatchGroup()
        var waitTime: UInt64 = 5 // default seconds
        var waitCount: Int = 0 // default lightCount
        let futureTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + waitTime * 1000000000)
        
        switch mode {
        // if mode is count, wait for light count before returning
        case .lightCount(let count):
            waitCount = count
            for _ in 0..<count {
                lightDispatch.enter()
            }
        // if mode is timeout, wait input-seconds before returning
        case .timeoutSeconds(let seconds):
            waitTime = UInt64(seconds)
            lightDispatch.enter()
        }
        
        
        guard let listener = try? NWListener(using: .udp, on: port) else {
            print("Listener failed")
            return
        }
        
        // Holds all the data received
        var dataArray: [Data] = []
        
        listener.newConnectionHandler = { (udpNewConn) in
            // create connection, listen to reply and save data
            udpNewConn.start(queue: self.serialQueue)
            
            self.receiver(udpNewConn, { (data) in
                
                switch mode {
                case .lightCount:
                    if dataArray.count < waitCount {
                        dataArray.append(data)
                        lightDispatch.leave()
                    }
                    
                case .timeoutSeconds:
                    dataArray.append(data)
                }
            })
        } // newConnectionHandler
        
        
        listener.start(queue: self.serialQueue)
        
        
        if lightDispatch.wait(timeout: futureTime) == .success {
            print("listener successfully returned \(waitCount) lights")
            
        } else {
            print("listener cancelled after \(futureTime.uptimeNanoseconds / 1000000000) seconds")
        }
        
        // pass data to the closure, cancel the listener and signal that the calling function can progress with the data
        closure(dataArray)
        listener.cancel()
        self.dispatchGroup.leave() // unlock 2
    } // UDPConnection.listener()
    
    
    
    public func sendSearchMessage(wait mode: DiscoveryWait, _ closure:@escaping ([Data]) -> Void) {
        
        var dataArray: [Data] = []
        
        
        // start connection
        self.dispatchGroup.enter() // lock 1
        self.searchConn.start(queue: self.serialQueue)
        
        // when conn.state is ready, continue executing function
        self.searchConn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .ready:
                print("udp connection ready")
                self.dispatchGroup.leave() // unlock 1
            case .waiting:
                print("No connection available")
            case .failed(let error):
                print("UDP connection returned error: \(error)")
            case .cancelled:
                print("UDP connection: cancelled")
            default:
                return
            }
        }
        
        
        // waiting for connection state to be .ready
        self.dispatchGroup.wait() // wait lock 1
        
        // send a search message
        self.searchConn.send(content: UDPConnection.searchBytes, completion: UDPConnection.sendCompletion)
        
        
        // safely unwrap local port
        guard let localPort = self.getLocalPort(fromConnection: self.searchConn) else {
            print("Couldn't find local port")
            return
        }
        
        
        self.dispatchGroup.enter() // lock 2
        // Listen for light replies and create a new light tcp connection
        self.listener(on: localPort, wait: mode, closure: { (allData) in
            dataArray = allData
        })
        
        // wait for UDPConnection.listener() to collect data and cancel connection
        self.dispatchGroup.wait() // wait lock 2 - unlock in listener()
        closure(dataArray)
        self.searchConn.cancel()
    } // UDPConnection.sendSearchMessage()
    
    
} // class UDPConnection



// ==========================================================================
// CLASS CONTROLLER =========================================================
// ==========================================================================



public class Controller {
    // aliases easier to read
    private typealias Property = String
    private typealias Value = String
    
    public typealias Alias = String
    public typealias ID = String
    
    // Stores all discovered lights as [idSerial : Data]
    public var lights: [String : Light] = [:]
    public var alias: [Alias : ID] = [:]
    
    // set default waitMode to stop discovery after 2 seconds
    private var stopDiscovery: DiscoveryWait = .timeoutSeconds(2)
    
    
    // parse string data to store light data
    private func parseProperties(Decoded decoded: String) -> [Property:Value] {
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
    private func decodeParseAndEstablish(_ data: Data) {
        
        // decode data to String
        guard let decoded: String = String(data: data, encoding: .utf8) else {
            print("UDP data message received cannot be decoded")
            return
        }
        
        // separate properties into dictionary to inspect
        let properties: [Property:Value] = self.parseProperties(Decoded: decoded)
        
        // create tcp connection to each light and save that connection and data
        // print errors identified
        // save the light to class dictionary
        do {
            guard let id = properties["id"] else {
                throw DiscoveryError.idValue
            }
            
            if self.lights[id] == nil {
                
                // Add new light to dictionary if doesn't already exist
                self.lights[id] = try self.createLight(properties)
            }
            
        }
        catch let error {
            print(error)
        }
        //throw DiscoveryError.idValue
        
        
    } // Controller.decodeHandler()
    
    
    
    // =====================================================================
    // CONTROLLER FUNCTIONS ================================================
    // =====================================================================
    
    
    
    public func discover(wait mode: DiscoveryWait) {
        
        var dataArray: [Data] = []
        
        // clear all existing lights and save the space in case of re-discovery
        self.lights.removeAll(keepingCapacity: true)
        
        let udp = UDPConnection()
        
        // establish
        udp.sendSearchMessage(wait: mode) { (data) in
            dataArray = data
        }
        
        if !dataArray.isEmpty {
            for data in dataArray {
                self.decodeParseAndEstablish(data)
            }
        }
        
    } // Controller.discover()
    
    
    // set an alias for the lights instead of remembering the IDs
    public func setLightAlias() {
        
    }
    
    
} // class Controller

