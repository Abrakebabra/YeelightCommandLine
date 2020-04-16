//
//  classLight.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/16.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network


// ==========================================================================
// CONTENTS =================================================================
// ==========================================================================

// public struct State
// public struct TCPConnection
// public struct Info
// public class  Light
    // public func communicate


// ==========================================================================
// SUPPORTING STRUCTS AND CLASSES ===========================================
// ==========================================================================



// The current state of the light's properties
public struct State {
    public var power: Bool
    public var colorMode: Int  //  Modes:  1 RGB, 2 Color Temp, 3 HSV
    public var brightness: Int  // Percentage:  1-100  (0 not valid)
    public var colorTemp: Int  // colorMode 2:  1700-6500 (Yeelight 2)
    public var rgb: Int  // colorMode 1:  1-16777215 (hex: 0xFFFFFF)
    public var hue: Int  // colorMode 3: 0-359
    public var sat: Int  // colorMode 3:  0-100
    
    public var flowing: Bool?  // flowing or not
    public var flowParams: [Int]?  // tuple (4 integers) per state
    public var musicMode: Bool?  // music mode on or off
    public var delayCountDownMins: Int?  // minutes until power off
    
    init(_ power: String,
         _ colorMode: String, _ brightness: String,
         _ colorTemp: String, _ rgb: String, _ hue: String, _ sat: String) {
        
        if power == "on" {
            self.power = true
        } else {
            self.power = false
        }
        
        // default values just in case a light that has been factory-reset has nil for properties that have not yet been used
        
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
    } // init()
} // struct State



// All things related to the tcp connection between program and light
public class TCPConnection: Connection {
    public var ip: String
    public var port: String
    public var id: String
    
    
    init(_ ip: String, _ port: String, _ id: String) throws {
        self.ip = ip
        self.port = port
        self.id = id
        
        guard let portEndpoint = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        
        let tcpParams = NWParameters.tcp
        tcpParams.acceptLocalOnly = true
        
        super.init(host: NWEndpoint.Host(ip), port: portEndpoint,
                   serialQueueLabel: "TCP Queue", connType: tcpParams)
        
    } // init
} // struct TCPConnection



// Identifying and useful information about light
public struct Info {
    public let id: String
    public let ip: String
    public var name: String
    public let model: String // Might be useful for lights with limited abilities
    public let support: String // Might be useful for lights with limited abilities
    
    init(_ id: String, _ ip: String, _ name: String, _ model: String, _ support: String) {
        self.id = id
        self.ip = ip
        self.name = name
        self.model = model
        self.support = support
    }
} // struct Info



// ==========================================================================
// CLASS LIGHT ==============================================================
// ==========================================================================



public class Light {
    
    public var state: State
    public var tcp: TCPConnection
    public var musicModeTCP: TCPConnection?
    public var info: Info
    public var requestTicket: Int = 0
    public var receiveLoop: Bool = true // turn to private later
    
    public enum Connection {
        case standardTCP
        case musicModeTCP
    }
    
    init(_ id: String, _ ip: String, _ port: String,
         _ power: String, _ colorMode: String, _ brightness: String,
         _ colorTemp: String, _ rgb: String, _ hue: String, _ sat: String,
         _ name: String, _ model: String, _ support: String) throws {
        
        // Holds the light's current state
        self.state = State(power, colorMode, brightness, colorTemp, rgb, hue, sat)
        
        // Holds the connection
        // throws if can't convert string to NWendpoint.Port
        self.tcp = try TCPConnection(ip, port, id)
        
        // Holds supporting information and identifiers
        self.info = Info(id, ip, name, model, support)
        
        
        // A constant receiver
        self.receiveAndUpdateState()
        
    } // Light.init()
    
    
    deinit {
        self.receiveLoop = false
        self.tcp.conn.cancel()
        // sleep(1) Should I give the receive function time to throw error and for the queue to deinitialize?
    } // Light.deinit()
    
    
    // update the state of the light
    private func updateState(_ key: String, _ value: Any) throws {
        switch key {
        case "power":
            guard let power = value as? String else {
                throw LightStateUpdateError.value("power to String failed")
            }
            
            self.state.power = power == "on" ? true : false
            
        case "bright":
            guard let brightness = value as? Int else {
                throw LightStateUpdateError.value("brightness to Int failed")
            }
            self.state.brightness = brightness
            
        case "color_mode":
            guard let colorMode = value as? Int else {
                throw LightStateUpdateError.value("colorTemp to Int failed")
            }
            self.state.colorMode = colorMode
            
        case "ct":
            guard let colorTemp = value as? Int else {
                throw LightStateUpdateError.value("colorTemp to Int failed")
            }
            self.state.colorTemp = colorTemp
            
        case "rgb":
            guard let rgb = value as? Int else {
                throw LightStateUpdateError.value("rgb to Int failed")
            }
            self.state.rgb = rgb
            
        case "hue":
            guard let hue = value as? Int else {
                throw LightStateUpdateError.value("hue to Int failed")
            }
            self.state.hue = hue
            
        case "sat":
            guard let sat = value as? Int else {
                throw LightStateUpdateError.value("sat to Int failed")
            }
            self.state.sat = sat
            
        case "name":
            guard let name = value as? String else {
                throw LightStateUpdateError.value("name to String failed")
            }
            self.info.name = name
            
        case "flowing":
            guard let flow = value as? Int else {
                throw LightStateUpdateError.value("flow state to Bool failed")
            }
            self.state.flowing = flow == 1 ? true : false
            
        case "flow_params":
            guard let params = value as? [Int] else {
                throw LightStateUpdateError.value("flow params to Array failed")
            }
            self.state.flowParams = params
            
        case "music_on":
            guard let musicMode = value as? Int else {
                throw LightStateUpdateError.value("music mode state to Bool failed")
            }
            self.state.musicMode = musicMode == 1 ? true : false
            
        case "delayoff":
            guard let mins = value as? Int else {
                throw LightStateUpdateError.value("delay countdown to Int failed")
            }
            self.state.delayCountDownMins = mins
            
        default:
            // don't throw error yet - might have more states that will update than anticipated
            print("Property key (\(key)) not handled.  Value is \(value)")
        } // switch
    } // Light.updateState()
    
    
    // decode response received from light and handle them
    private func jsonDecodeAndHandle(_ data: Data) throws {
        /*
         JSON RESPONSES
         
         Standard Responses
         {"id":1, "result":["ok"]}
         get_pro Response
         {"id":1, "result":["on", "", "100"]}
         
         Error Response
         {"id":2, "error":{"code":-1, “message”:"unsupported method"}}
         [String:[String:Any]]
         
         UNUSED:
         cron_get Response      [[String:Int]]
         {"id":1, "result":[{"type": 0, "delay": 15, "mix": 0}]}
         Won't use this response.
         cron methods can only turn off light after X minutes.  No need for a timer function.
         
         Sent to all tcp connections when state changed:
         {"method":"props","params":{"ct":6500}}
         */
        
        /*
         Deserialize to json object
         Top level "result" key?  If yes, print results.
         Top level "error" key?  If yes, print error.
         Top level "params" key?  If yes, update light state with new data.
 
        */
        
        
        // jsonserialization object
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        // unpack the top level json object
        guard let topLevel = json as? [String:Any] else {
            throw JSONError.jsonObject
        }
        
        // results
        if let resultList = topLevel["result"] as? [String] {
            if let id = topLevel["id"] as? Int {
                // if there is a resultList
                print("id \(id): \(resultList)")
            } else {
                print("No id: \(resultList)")
            }
            
        // errors
        } else if let error = topLevel["error"] as? [String:Any] {
            guard
                let errorCode: Int = error["code"] as? Int,
                let errorMessage: String = error["message"] as? String
                else {
                    // if can't unpack error object
                    throw JSONError.errorObject
            }
            
            if let id = topLevel["id"] as? Int {
                throw JSONError.response("id: \(id)  Error Code \(errorCode): \(errorMessage)")
            } else {
                throw JSONError.response("Error Code \(errorCode): \(errorMessage)")
            }
        
        // change in state
        } else if let changedState = topLevel["params"] as? [String:Any] {
            for (key, value) in changedState {
                // switch function for updating state
                try self.updateState(key, value)
                print("\(self.info.id) updating '\(key)' to '\(value)'")
            }
            
        } else {
            throw JSONError.unknown(json as Any)
        }
        
    } // Light.jsonDecode()
    
    
    // handles the receiving from tcp conn with light
    private func receiveAndUpdateState() -> Void {
        self.tcp.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, error) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            
            if self.receiveLoop == false {
                return
            }
            
            if error != nil {
                self.receiveLoop = false
                print("\(self.info.id), \(self.info.ip):  \(error.debugDescription)")
                return
            }
            
            if let data = data {
                do {
                    // receives tcp messages and handles them
                    try self.jsonDecodeAndHandle(data)
                }
                catch let handlingError {
                    print(handlingError)
                }
            }
            
            // recurse
            if self.receiveLoop == true {
                self.receiveAndUpdateState()
            }
            
        } // conn.receive closure
    } // Light.receiveAndUpdateState()
    
    
    // Send a command to the light
    public func communicate(_ methodParams: String) {
        // takes in a command
        // randomly generate an ID for that message
        // append string command to ID
        // convert to data
        // sends message to light
        // append ID to a dictionary with the message
        // awaits for a reply
        // sort through various replies or errors from light
        // return that reply to what called the function
        // throw errors found in JSON reply from light
        
        self.requestTicket += 1
        
        let id: String = """
        "id":\(self.requestTicket)
        """
        
        let message: String = """
        {\(id), \(methodParams)}\r\n
        """
        
        print(message)  // FOR FUTURE DEBUGGING PURPOSES
        
        let requestContent = message.data(using: .utf8)
        
        self.tcp.conn.send(content: requestContent, completion: self.tcp.sendCompletion)
        
    } // Light.communicate()
    
    
    
    
    
    
} // class Light



