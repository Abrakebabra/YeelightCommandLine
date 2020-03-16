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
 
 struct light properties
 
 
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
    let port: Int
    let idSerial: String
    
    let server: String
    let model: String
    let fw_ver: String
    let support: String
    
    var power: Bool
    var brightness: Int
    var colorMode: Int
    var colorTemp: Int
    var rgb: Int
    var hue: Int
    var sat: Int
    var name: String
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
        func createLight(dict input: [String:String]) -> State {
            
            // temporary holding of values to init
            var ip: String = ""
            var port: Int = 0
            var idSerial: String = ""
            
            var server: String = ""
            var model: String = ""
            var fw_ver: String = ""
            var support: String = ""
            
            var power: Bool = false
            var brightness: Int = 1
            var colorMode: Int = 1
            var colorTemp: Int = 1700
            var rgb: Int = 0
            var hue: Int = 0
            var sat: Int = 0
            var name: String = ""
            
            
            // initialise string, bool and int properties
            for (key, value) in input {
                switch key {
                case "ip":
                    ip = value
                case "port":
                    if let intPort = Int(value) {
                        port = intPort
                    }
                case "Server":
                    server = value
                case "id":
                    idSerial = value
                case "model":
                    model = value
                case "fw_ver":
                    fw_ver = value
                case "support":
                    support = value
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
                default:
                    continue
                }
            }
            
            let newLight = State(ip: ip, port: port, idSerial: idSerial, server: server, model: model, fw_ver: fw_ver, support: support, power: power, brightness: brightness, colorMode: colorMode, colorTemp: colorTemp, rgb: rgb, hue: hue, sat: sat, name: name)
            
            return newLight
        }
        
        
        
        // parse string data to store light data
        func parseData(Decoded decoded: String) -> State {
            // parse the information received into struct
            var separatedProperties: [String] = decoded.components(separatedBy: "\r\n")
            separatedProperties.removeFirst()
            separatedProperties.removeLast()
            let addressMarker: String = "Location: yeelight://"
            var dictionaryProperties: [String: String] = [:]
            
            
            for i in separatedProperties {
                if i.contains(addressMarker) {
                    let ipPortString: String = i.replacingOccurrences(of: addressMarker, with: "")
                    let ipPort: [String] = ipPortString.components(separatedBy: ":")
                    dictionaryProperties["ip"] = ipPort[0]
                    dictionaryProperties["port"] = ipPort[1]
                    
                } else {
                    let keyValue: [String] = i.components(separatedBy: ":")
                    let key: String = keyValue[0]
                    let value: String = keyValue[1]
                    dictionaryProperties[key] = value
                }
            }
            return createLight(dict: dictionaryProperties)
        }
    
        
        // reads data array and stores meaningful light information
        func extractData(Received data: Data) {
            // convert data into string
            let decoded: String = String(data: data, encoding: .utf8)!
            // manipulate string into separate data properties
            
            let lightData: State = parseData(Decoded: decoded)
            self.light[lightData.idSerial] = lightData
            
        }
        
        
        // handles replies received from lights with listener
        func udpReplyHandler(newConn conn: NWConnection) {
            // starts connection
            // receives data from connection
            // if complete, cancels the connection
            
            conn.start(queue: connQueue)
            
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: { (data, _, _, _) in
                // data, defaultMessage, isComplete, errors (enum dns posix tcl)
                
                if let data: Data = data, !data.isEmpty {
                    extractData(Received: data)
                    // won't need the connection anymore
                    conn.cancel()
                }
                // Handle NW errors?
            })
        }
        
        
        // Listen for reply from multicast
        func udpListenReply(onPort port: NWEndpoint.Port) {
            
            if let listener = try? NWListener(using: .udp, on: port) {
                listener.newConnectionHandler = { (newConn) in
                    udpReplyHandler(newConn: newConn)
                    
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
            //if let NWError = NWError {
            //    print(NWError)
            //}
        }
        
        // Start the connection
        udpConn.start(queue: connQueue)
        
        
        // Send search message and handle replies
        udpConn.send(content: searchBytes, completion: sendSearchCompletion)
        
    }
}

