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

public struct State {
    let ip: String
    let port: String
    let idSerial: String
    let conn: TCPConnection

    var power: Bool
    var brightness: Int
    var colorMode: Int
    var colorTemp: Int
    var rgb: Int
    var hue: Int
    var sat: Int
    var name: String
    
    let model: String // Might be useful for lights with limited abilities
    let support: String // Might be useful for lights with limited abilities
    
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
        func createLight(dict input: [String:String]) throws -> State {
            
            // temporary holding of values to init
            var ip: String = ""
            var port: String = ""
            var idSerial: String = ""
            
            var model: String = ""
            var support: String = ""
            
            var power: Bool = false
            var brightness: Int = 1
            var colorMode: Int = 1
            var colorTemp: Int = 1700
            var rgb: Int = 0
            var hue: Int = 0
            var sat: Int = 0
            var name: String = ""
            
            
            // initialise string, bool and int propertyList
            for (key, value) in input {
                switch key {
                case "ip":
                    ip = value
                case "port":
                    port = value
                case "id":
                    idSerial = value
                case "power":
                    if value == "on" {
                        power = true
                    }
                case "bright":
                    if let intBright = Int(value) {
                        brightness = intBright
                    }
                case "color_mode":
                    if let intColMode = Int(value) {
                        colorMode = intColMode
                    }
                case "ct":
                    if let intColTemp = Int(value) {
                        colorTemp = intColTemp
                    }
                case "rgb":
                    if let intRGB = Int(value) {
                        rgb = intRGB
                    }
                case "hue":
                    if let intHue = Int(value) {
                        hue = intHue
                    }
                case "sat":
                    if let intSat = Int(value) {
                        sat = intSat
                    }
                case "name":
                    name = value
                case "model":
                    model = value
                case "support":
                    support = value
                default:
                    continue
                }
            }
            
            let tcpConnection = try TCPConnection(TargetIP: ip, TargetPort: port, ID: idSerial)
            
            return State(ip: ip, port: port, idSerial: idSerial, conn: tcpConnection, power: power, brightness: brightness, colorMode: colorMode, colorTemp: colorTemp, rgb: rgb, hue: hue, sat: sat, name: name, model: model, support: support)
        }
        
        
        // parse string data to store light data
        func parseData(Decoded decoded: String) -> [String:String] {
            // parse the information received into struct
            var propertyList: [String] = decoded.components(separatedBy: "\r\n")
            propertyList.removeFirst() // remove HTTP header
            propertyList.removeLast() // remove empty element
            // could probably put above in own function
            
            let addressMarker: String = "Location: yeelight://"
            var propertyDict: [String: String] = [:]
            
            
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
            
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: { (data, _, _, _) in
                // data, defaultMessage, isComplete, errors (enum dns posix tcl)
                
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
                    let lightData: State = try createLight(dict: properties)
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
            })
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

