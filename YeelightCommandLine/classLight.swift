//
//  classLight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network



struct State {
    var power: Bool
    var colorMode: Int, brightness: Int
    var colorTemp: Int, rgb: Int, hue: Int, sat: Int
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
    let dispatchGroup: DispatchGroup
    
    
    init(_ ip: String, _ port: String) throws {
        self.ipEndpoint = NWEndpoint.Host(ip)
        guard let portEndpoint = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        self.portEndpoint = portEndpoint
        self.conn = NWConnection.init(host: self.ipEndpoint, port: self.portEndpoint, using: .tcp)
        self.status = "unknown"
        self.dispatchGroup = DispatchGroup()
        self.conn.start(queue: connQueue)
    }
} // struct TCPConnection



public class Light {
    let id: String
    var name: String
    let ip: String
    var state: State
    var tcp: TCPConnection

    let sendCompletion: NWConnection.SendCompletion
    
    
    init(ip: String, port: String, id: String,
         power: String,
         colorMode: String, brightness: String,
         colorTemp: String, rgb: String, hue: String, sat: String,
         name: String,
         model: String, support: String) throws {
        
        self.id = id
        self.name = name
        self.ip = ip
        
        // Holds the light's current state
        self.state = State(power, colorMode, brightness, colorTemp, rgb, hue, sat, model, support)
        
        // Holds the connection
        // throws if can't convert string to NWendpoint.Port
        self.tcp = try TCPConnection(ip, port)
        
        
        self.sendCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            if NWError != nil {
                print("TCP error in message sent:\n  ID: \(self.id)\n  IP: \(self.ip)\n  Error: \(NWError as Any)")
            } else {
                print("TCP message successfully sent to \(self.id), \(self.ip)")
            }
        }
        
        
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
                print("Unknown error for \(self.ip), \(self.id).  Restarting.")
                self.tcp.conn.restart()
            }
        }
        
        
        
    } // Light.init()
    
    
    // Send a command to the light
    func commandAndResponse(CommandString commandData: Data) throws -> [String] {
        // takes in JSON string
        // sends that to a light
        // awaits for a reply
        // sort through various replies or errors from light
        // time out error too
        // return that reply to what called the function
        // throw errors found in JSON reply from light
        
        var responseData: Data?
        
        self.tcp.conn.send(content: commandData, completion: self.sendCompletion)
        
        self.tcp.dispatchGroup.enter()
        self.tcp.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, NWError) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            if NWError != nil {
                print(NWError as Any)
                self.tcp.dispatchGroup.leave()
                return
                
            } else {
                responseData = data
                self.tcp.dispatchGroup.leave()
            }
        }
        
        self.tcp.dispatchGroup.wait()
        let reply = try jsonDecoder(Response: responseData)
        
        return reply
    } // commandAndResponse
    
    
    
    
} // class Light


