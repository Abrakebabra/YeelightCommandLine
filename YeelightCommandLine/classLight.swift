//
//  classLight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network


public class Light {
    let id: String
    var name: String
    var power: Bool
    var colorMode: Int, brightness: Int
    var colorTemp: Int, rgb: Int, hue: Int, sat: Int
    let model: String // Might be useful for lights with limited abilities
    let support: String // Might be useful for lights with limited abilities
    
    let ip: String, ipEndpoint: NWEndpoint.Host
    let port: String, portEndpoint: NWEndpoint.Port
    
    
    let conn: NWConnection
    var status: String
    let tcpDispatchGroup: DispatchGroup
    
    let complete = NWConnection.SendCompletion.contentProcessed { (NWError) in
        if NWError != nil {
            print("TCP error in message sent:  \(NWError as Any)")
        } else {
            print("TCP message successfully sent")
        }
    }
    
    init(ip: String, port: String, id: String,
         power: String,
         colorMode: String, brightness: String,
         colorTemp: String, rgb: String, hue: String, sat: String,
         name: String,
         model: String, support: String) throws {
        
        self.id = id
        self.name = name
        
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
        
        self.ip = ip
        self.ipEndpoint = NWEndpoint.Host(self.ip)
        self.port = port
        guard let portEndpoint = NWEndpoint.Port(self.port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        self.portEndpoint = portEndpoint
        
        self.conn = NWConnection.init(host: self.ipEndpoint, port: self.portEndpoint, using: .tcp)
        
        self.status = "unknown"
        
        self.tcpDispatchGroup = DispatchGroup()
        
        self.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.status = "setup"
            case .preparing:
                self.status = "preparing"
            case .ready:
                self.status = "ready"
                print("\(self.ip), \(self.id) ready")
            case .waiting:
                self.status = "waiting"
                print("\(self.ip), \(self.id) waiting")
            case .failed:
                self.status = "failed"
                print("\(self.ip), \(self.id) tcp connection failed.  Restarting.")
                self.conn.restart()
            case .cancelled:
                self.status = "cancelled"
                print("\(self.ip), \(self.id) tcp connection cancelled")
            default:
                self.status = "unknown"
                print("Unknown error for \(self.ip), \(self.id).  Restarting.")
                self.conn.restart()
            }
        }
        
        self.conn.start(queue: connQueue)
        
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
        
        self.conn.send(content: commandData, completion: complete)
        
        self.tcpDispatchGroup.enter()
        self.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, NWError) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            if NWError != nil {
                print(NWError as Any)
                self.tcpDispatchGroup.leave()
                return
                
            } else {
                responseData = data
                self.tcpDispatchGroup.leave()
            }
        }
        
        self.tcpDispatchGroup.wait()
        let reply = try jsonDecoder(Response: responseData)
        
        return reply
    } // commandAndResponse
    
    
    
    
} // class Light


