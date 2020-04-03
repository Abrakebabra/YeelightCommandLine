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



public class Yeelight {
    // Stores all discovered lights as [idSerial : Data]
    public var light: [String : Light] = [:]
    
    // search addr, port
    private static let multicastHost: NWEndpoint.Host = "239.255.255.250"
    private static let multicastPort: NWEndpoint.Port = 1982
    
    // search message
    private static let searchMsg: String = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: \"ssdp:discover\"\r\nST: wifi_bulb"
    private static let searchBytes = searchMsg.data(using: .utf8)
    
    
    public func discover() {
        // aliases easier to read
        typealias Key = String
        typealias Property = String
        typealias Components = [String]
        
        // convert strings to data types and create struct
        func createLight(
            Properties property: [Key:Property])
            throws -> Light {
            
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
                    throw DiscoveryError.propertyStringUnwrapFailed
            }
            
            let tcpConnection = try TCPConnection(TargetIP: ip, TargetPort: port, ID: idSerial)
            
            let state = Light(IP: ip, Port: port, IDSerial: idSerial, Conn: tcpConnection, Power: power, ColorMode: colorMode, Brightness: brightness, ColorTemp: colorTemp, RGB: rgb, Hue: hue, Sat: sat, Name: name, Model: model, Support: support)
            
            return state
        } // END createLight
        
        
        // parse string data to store light data
        func parseData(Decoded decoded: String) -> [Key:Property] {
            // dictionary of all properties cleaned and separated
            var propertyDict: [Key:Property] = [:]
            
            // separate message string into separate lines
            var propertyList: Components =
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
                    let keyValue: Components =
                        i.components(separatedBy: ": ")
                    let key: Key = keyValue[0]
                    let value: Property = keyValue[1]
                    propertyDict[key] = value
                }
            }
            // possible to return empty
            return propertyDict
        } // END parseData
        
        
        // handles replies received from lights with listener
        func udpReplyHandler(NewConn udpConn: NWConnection) {
            
            udpConn.start(queue: connQueue)
            
            udpConn.receiveMessage { (data, _, _, _) in
                // Data?, contentContext?, Bool, NWError? (enum dns posix tcl)
                
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
                let properties: [Key:Property] = parseData(Decoded: decoded)
                
                // create tcp connection to each light and save that connection and data
                // print errors identified
                do {
                    let lightData: Light = try createLight(Properties: properties)
                    // save the light to class dictionary
                    self.light[lightData.idSerial] = lightData
                }
                catch let error {
                    print(error)
                }
                
                // No use for discovery socket anymore
                udpConn.cancel()
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
        
        
        ///////////////////////////////////////////////////////////////
        
        
        // clear all existing lights
        self.light.removeAll(keepingCapacity: true)
        
        // Setup UDP connection
        let udpSearchConn = NWConnection(host: Yeelight.multicastHost, port: Yeelight.multicastPort, using: .udp)
        
        // Start the connection
        udpSearchConn.start(queue: connQueue)
        
        
        // Setup procedure to do when search message is sent
        let awaitResponses = NWConnection.SendCompletion.contentProcessed { (NWError) in
            // get local port
            // listen for replies from lights on that port
            // dump data into array
            if NWError != nil {
                print(NWError as Any)
                return
                
            } else {
                // Get local port.  If returns nil, notify then end discovery
                guard let localPort = getLocalPort(fromConnection: udpSearchConn) else {
                    print("Couldn't find local port")
                    return
                }
                
                // Listen for light replies and create a new light tcp connection
                udpListenReply(onPort: localPort)
            }
        }
        
        
        // Send search message
        udpSearchConn.send(content: Yeelight.searchBytes, completion: awaitResponses)
        
    } // END discover()
    
    /*
    func setPower(LightID light: String, Power state: Bool) {
        if state == true {
            
        }
    }
    */
    
}

