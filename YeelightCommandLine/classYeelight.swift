//
//  yeelight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/10.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network



/*
 
 struct light propertyList
 
 
 Light Class
 let DispatchQueue("Network Queue") (Or one for outgoing one for incoming?)
 let DispatchQueue("background/wait queue?")
 
 func discover()
 let multiHost
 let multiPort
 let byteMessage
 
 create UDP connection
 udpConnection state handler?
 start UDP connection - What if connection fails?  Error?
 setup send completion procedure - handle send error
 get local port - handle error
 setup replyListen function
 SEND
 Listen to replies and dump all data
 Sift through data, sort and create light instances?
  - How should I store the lights?
    - Dictionary of ID followed by data?
    - Light objects?
    -
 
 Perhaps discover network code in a separate class?
 
 */

// I can do the initialising here and convert all strings to integers
// It's not really a "State" anymore, since I have the connection object here
// Change struct name?
public struct Light {
    let ip: String, port: String, idSerial: String, conn: TCPConnection
    var power: Bool
    var colorMode: Int, brightness: Int
    var colorTemp: Int, rgb: Int, hue: Int, sat: Int
    var name: String
    let model: String // Might be useful for lights with limited abilities
    let support: String // Might be useful for lights with limited abilities
    
    
    init(IP: String, Port: String, IDSerial: String, Conn: TCPConnection,
         Power: String,
         ColorMode: String, Brightness: String,
         ColorTemp: String, RGB: String, Hue: String, Sat: String,
         Name: String,
         Model: String, Support: String) {
        self.ip = IP
        self.port = Port
        self.idSerial = IDSerial
        self.conn = Conn
        
        if Power == "on" {
            self.power = true
        } else {
            self.power = false
        }
        
        // just in case a light that has been factory-reset has nil for properties that have not yet been used
        // or do I want to throw an error?  It's not really an error for the user to deal with if the light hasn't initialised it and will do so later.
        
        if let colorModeInt = Int(ColorMode) {
            self.colorMode = colorModeInt
        } else {
            self.colorMode = 1
        }
        if let brightInt = Int(Brightness) {
            self.brightness = brightInt
        } else {
            self.brightness = 1
        }
        if let colorTempInt = Int(ColorTemp) {
            self.colorTemp = colorTempInt
        } else {
            self.colorTemp = 1700
        }
        if let rgbInt = Int(RGB) {
            self.rgb = rgbInt
        } else {
            self.rgb = 0
        }
        if let hueInt = Int(Hue) {
            self.hue = hueInt
        } else {
            self.hue = 0
        }
        if let satInt = Int(Sat) {
            self.sat = satInt
        } else {
            self.sat = 0
        }
        
        self.name = Name
        self.model = Model
        self.support = Support
    }
}


public class Yeelight {
    // Stores all lights
    public var light: [String : State] = [:]
    
    // no init func yet
    
    public func discover() {
        
        // clear all existing lights
        light.removeAll(keepingCapacity: true)
        
        // enter expected number of lights to find?
        // or find them all, then prompt if it looks right
        
        // searchMessage addr, port, and message
        let multicastHost: NWEndpoint.Host = "239.255.255.250"
        let multicastPort: NWEndpoint.Port = 1982
        let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
        let searchBytes = searchMsg.data(using: .utf8)
        
        
        // Setup UDP connection
        let udpConn = NWConnection(host: multicastHost, port: multicastPort, using: .udp)
        
        
        // convert strings to various data types and create struct
        // handle errors?
        func createLight(Dict property: [String:String]) throws -> Light {
            
            guard
                let ip = property["ip"],
                let port = property["port"],
                let idSerial = property["id"],
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
                    throw DiscoveryError.stringUnwrapFailed
            }
            
            let tcpConnection = try TCPConnection(TargetIP: ip, TargetPort: port, ID: idSerial)
            
            let state = Light(IP: ip, Port: port, IDSerial: idSerial, Conn: tcpConnection, Power: power, ColorMode: colorMode, Brightness: brightness, ColorTemp: colorTemp, RGB: rgb, Hue: hue, Sat: sat, Name: name, Model: model, Support: support)
            
            return state
        }
        
        
        // parse string data to store light data
        func parseData(Decoded decoded: String) -> [String:String] {
            // parse the information received into struct
            var propertyList: [String] = decoded.components(separatedBy: "\r\n")
            propertyList.removeFirst() // remove HTTP header
            propertyList.removeLast() // remove empty element
            // could probably put above in own function
            
            let addressMarker: String = "Location: yeelight://"
            var propertyDict: [String:String] = [:]
            
            
            for i in propertyList {
                if i.contains(addressMarker) {
                    let ipPortString: String = i.replacingOccurrences(of: addressMarker, with: "")
                    let ipPort: [String] = ipPortString.components(separatedBy: ":")
                    propertyDict["ip"] = ipPort[0]
                    propertyDict["port"] = ipPort[1]
                    
                } else {
                    let keyValue: [String] = i.components(separatedBy: ":")
                    let key: String = keyValue[0]
                    let value: String = keyValue[1]
                    propertyDict[key] = value
                }
            }
            return propertyDict
        }
        
        
        // handles replies received from lights with listener
        func udpReplyHandler(NewConn conn: NWConnection) {
            
            conn.start(queue: connQueue)
            
            conn.receiveMessage { (data, _, _, _) in
                // Data?, contentContext?, Bool, NWError? (enum dns posix tcl)
                
                // data is valid?
                guard let unwrappedData: Data = data else {
                    return
                }
                
                // decode data to String
                guard let decoded: String = String(data: unwrappedData, encoding: .utf8) else {
                    return
                }
                
                // separate properties into dictionary to inspect
                let properties: [String:String] = parseData(Decoded: decoded)
                
                // create struct of light property
                do {
                    let lightData: State = try createLight(Dict: properties)
                    // save the light to class dictionary
                    self.light[lightData.idSerial] = lightData
                    
                    // reduce number of expected lights
                    lightsRemaining -= 1
                }
                catch {
                    print("TCP Init Failed")
                    return
                }
                
                // won't need the connection anymore
                conn.cancel()
                
            }
            
        }
        
        
        // Listen for reply from multicast
        func udpListenReply(onPort port: NWEndpoint.Port) {
            
            if let listener = try? NWListener(using: .udp, on: port) {
                listener.newConnectionHandler = { (newConn) in
                    // create connection, listen to reply and create lights from data received
                    udpReplyHandler(NewConn: newConn)
                    
                }
                listener.start(queue: connQueue)
            }
        }
        
        
        // Setup procedure to do when search message is sent
        let sendSearchCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            // get local port
            // listen for replies from lights on that port
            // dump data into array
            if NWError == nil {
                if let localPort = getLocalPort(fromConnection: udpConn) {
                    // what if there's no data?  Handle that error?
                    udpListenReply(onPort: localPort)
                    
                }
            }
        }
        
        // Start the connection
        udpConn.start(queue: connQueue)
        
        
        // Send search message and handle replies
        udpConn.send(content: searchBytes, completion: sendSearchCompletion)
        
        
        
        
    }
    
    
    
}

