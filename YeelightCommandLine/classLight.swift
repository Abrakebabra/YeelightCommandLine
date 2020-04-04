//
//  classLight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network


// STRUCTS


struct State {
    var power: Bool
    var colorMode: Int  //  Modes:  1 RGB, 2 Color Temp, 3 HSV
    var brightness: Int  // Percentage:  1-100  (0 not valid)
    var colorTemp: Int  // colorMode 2:  1700-6500 (Yeelight 2)
    var rgb: Int  // colorMode 1:  0-16777215 (hex: 0xFFFFFF)
    var hue: Int  // colorMode 3: 0-359
    var sat: Int  // colorMode 3:  0-100
    let model: String // Might be useful for lights with limited abilities
    let support: String // Might be useful for lights with limited abilities
    
    
    init(_ power: String,
         _ colorMode: String, _ brightness: String,
         _ colorTemp: String, _ rgb: String, _ hue: String, _ sat: String,
         _ model: String,
         _ support: String) {
        
        if power == "on" {
            self.power = true
        } else {
            self.power = false
        }
        
        // just in case a light that has been factory-reset has nil for properties that have not yet been used
        // or do I want to throw an error?  It's not really an error for the user to deal with if the light hasn't initialised it and will do so later.
        
        if let colorModeInt = Int(colorMode) {
            self.colorMode = colorModeInt
        } else {
            self.colorMode = 1
        }
        if let brightInt = Int(brightness) {
            self.brightness = brightInt
        } else {
            self.brightness = 1
        }
        if let colorTempInt = Int(colorTemp) {
            self.colorTemp = colorTempInt
        } else {
            self.colorTemp = 1700
        }
        if let rgbInt = Int(rgb) {
            self.rgb = rgbInt
        } else {
            self.rgb = 0
        }
        if let hueInt = Int(hue) {
            self.hue = hueInt
        } else {
            self.hue = 0
        }
        if let satInt = Int(sat) {
            self.sat = satInt
        } else {
            self.sat = 0
        }
        
        self.model = model
        self.support = support
    }
} // struct State



struct TCPConnection {
    let ipEndpoint: NWEndpoint.Host
    let portEndpoint: NWEndpoint.Port
    let conn: NWConnection
    var status: String
    let dispatchQueue: DispatchQueue
    let dispatchGroup: DispatchGroup
    
    
    init(_ ip: String, _ port: String) throws {
        self.ipEndpoint = NWEndpoint.Host(ip)
        guard let portEndpoint = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        self.portEndpoint = portEndpoint
        self.conn = NWConnection.init(host: self.ipEndpoint, port: self.portEndpoint, using: .tcp)
        self.status = "unknown"
        self.dispatchQueue = DispatchQueue(label: "tcpConn Queue")
        self.dispatchGroup = DispatchGroup()
        
        self.conn.start(queue: self.dispatchQueue)
    }
} // struct TCPConnection



////////////////////////////////////////////////////////////////////////////


// CLASS



/*
 Send message
 - Currently receiving?  If not...
  - In new thread, open receive and mark as currently receiving
  -
 */


public class Light {
    let id: String
    let ip: String
    var name: String
    var state: State
    var tcp: TCPConnection
    
    
    init(_ id: String, _ ip: String, _ port: String, _ name: String,
         _ power: String, _ colorMode: String, _ brightness: String,
         _ colorTemp: String, _ rgb: String, _ hue: String, _ sat: String,
         _ model: String, _ support: String) throws {
        
        self.id = id
        self.name = name
        self.ip = ip
        
        // Holds the light's current state
        self.state = State(power, colorMode, brightness, colorTemp, rgb, hue, sat, model, support)
        
        // Holds the connection
        // throws if can't convert string to NWendpoint.Port
        self.tcp = try TCPConnection(ip, port)
        
        self.tcp.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.tcp.status = "setup"
            case .preparing:
                self.tcp.status = "preparing"
            case .ready:
                self.tcp.status = "ready"
                print("\(self.ip), \(self.id) ready")
            case .waiting:
                self.tcp.status = "waiting"
                print("\(self.ip), \(self.id) waiting")
            case .failed:
                self.tcp.status = "failed"
                print("\(self.ip), \(self.id) tcp connection failed.  Restarting.")
                self.tcp.conn.restart()
            case .cancelled:
                self.tcp.status = "cancelled"
                print("\(self.ip), \(self.id) tcp connection cancelled")
            default:
                self.tcp.status = "unknown"
                print("Unknown status for \(self.ip), \(self.id)")
            } // switch
        } // stateUpdateHandler
    } // Light.init()
    
    
    func updateState(method: String, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) throws {
        
        switch method {
        case "set_ct_abx":
            
            guard let colorTemp = param1 as? Int else {
                throw LightStateError.param1("param1 colorTemp to Int failed")
            }
            self.state.colorTemp = colorTemp
            self.state.colorMode = 2
            
        case "set_rgb":
            
            guard let rgb = param1 as? Int else {
                throw LightStateError.param1("param1 rgb to Int failed")
            }
            self.state.rgb = rgb
            self.state.colorMode = 1
            
        case "set_hsv":
            
            guard let hue = param1 as? Int else {
                throw LightStateError.param1("param1 hue to Int failed")
            }
            self.state.hue = hue
            
            guard let sat = param2 as? Int else {
                throw LightStateError.param1("param1 sat to Int failed")
            }
            self.state.sat = sat
            self.state.colorMode = 3
            
        case "set_bright":
            
            guard let brightness = param1 as? Int else {
                throw LightStateError.param1("param1 brightness to Int failed")
            }
            self.state.brightness = brightness
            
        case "set_power":
            
            guard let power = param1 as? String else {
                throw LightStateError.param1("param1 power to String failed")
            }
            if power == "on" {
                self.state.power = true
            } else {
                self.state.power = false
            }
            
        case "set_scene":
            
            // action trying to chaange rgb, ct or hsv?
            guard let action = param1 as? String else {
                throw LightStateError.param1("param1 set_scene to String failed")
            }
            
            switch action {
            case "color":
                guard let rgb = param2 as? Int else {
                    throw LightStateError.param1("param2 rgb to Int failed")
                }
                self.state.rgb = rgb
                self.state.colorMode = 1
                
                guard let brightness = param3 as? Int else {
                    throw LightStateError.param1("param3 brightness to Int failed")
                }
                self.state.brightness = brightness
                
            case "ct":
                guard let colorTemp = param2 as? Int else {
                    throw LightStateError.param1("param2 colorTemp to Int failed")
                }
                self.state.colorTemp = colorTemp
                self.state.colorMode = 2
                
                guard let brightness = param3 as? Int else {
                    throw LightStateError.param1("param3 brightness to Int failed")
                }
                self.state.brightness = brightness
                
            case "hsv":
                
            default:
                
                
            }
            
        case "set_name":
        case "adjust_bright":
        case "adjust_ct":
        case "adjust_color":
        default:
            
        }
    }
    
    
    // Send a command to the light
    func communicate(reqID: Int, method: String, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) throws {
        // takes in a string
        // randomly generate an ID for that message
        // append string command to ID
        // convert to data
        // sends message to light
        // append ID to a dictionary with the message
        // awaits for a reply
        // sort through various replies or errors from light
        // return that reply to what called the function
        // throw errors found in JSON reply from light
        
        
        
        
        
        var responseData: Data?
        
        let sendCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            if NWError != nil {
                print("TCP error in message sent:\n  ID: \(self.id)\n  IP: \(self.ip)\n  Error: \(NWError as Any)")
            } else {
                print("TCP message successfully sent to \(self.id), \(self.ip)")
            }
        } // sendCompletion\
        
        // self.tcp.conn.send(content: commandData, completion: sendCompletion)
        
        
        
        
        
        self.tcp.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, NWError) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            if NWError != nil {
                print(NWError as Any)
                return
                
            } else {
                responseData = data
            }
        } // conn.receive
        
        
        
    } // commandAndResponse
    
    
    
    
} // class Light


