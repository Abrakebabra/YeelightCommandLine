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

// The current state of the light's properties
public struct State {
    public var power: Bool
    public var colorMode: Int  //  Modes:  1 RGB, 2 Color Temp, 3 HSV
    public var brightness: Int  // Percentage:  1-100  (0 not valid)
    public var colorTemp: Int  // colorMode 2:  1700-6500 (Yeelight 2)
    public var rgb: Int  // colorMode 1:  1-16777215 (hex: 0xFFFFFF)
    public var hue: Int  // colorMode 3: 0-359
    public var sat: Int  // colorMode 3:  0-100
    
    
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
public struct TCPConnection {
    public let ipEndpoint: NWEndpoint.Host
    public let portEndpoint: NWEndpoint.Port
    
    public let conn: NWConnection
    public var status: String
    private let dispatchQueue: DispatchQueue
    
    
    init(_ ip: String, _ port: String) throws {
        self.ipEndpoint = NWEndpoint.Host(ip)
        guard let portEndpoint = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        self.portEndpoint = portEndpoint
        self.conn = NWConnection.init(host: self.ipEndpoint, port: self.portEndpoint, using: .tcp)
        self.status = "unknown"
        self.dispatchQueue = DispatchQueue(label: "tcpConn Queue", attributes: .concurrent)
        
        self.conn.start(queue: self.dispatchQueue)
    }
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



////////////////////////////////////////////////////////////////////////////



public class Light {
    
    public var state: State
    public var tcp: TCPConnection
    public var info: Info
    public var requestTicket: Int = 0
    public var receiverLoop: Bool = true // make this private later
    
    
    init(_ id: String, _ ip: String, _ port: String,
         _ power: String, _ colorMode: String, _ brightness: String,
         _ colorTemp: String, _ rgb: String, _ hue: String, _ sat: String,
         _ name: String, _ model: String, _ support: String) throws {
        
        // Holds the light's current state
        self.state = State(power, colorMode, brightness, colorTemp, rgb, hue, sat)
        
        // Holds the connection
        // throws if can't convert string to NWendpoint.Port
        self.tcp = try TCPConnection(ip, port)
        
        // Holds supporting information and identifiers
        self.info = Info(id, ip, name, model, support)
        
        self.tcp.conn.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .setup:
                self.tcp.status = "setup"
            case .preparing:
                self.tcp.status = "preparing"
            case .ready:
                self.tcp.status = "ready"
                print("\(self.info.ip), \(self.info.id) ready")
            case .waiting:
                self.tcp.status = "waiting"
                print("\(self.info.ip), \(self.info.id) waiting")
            case .failed:
                self.tcp.status = "failed"
                print("\(self.info.ip), \(self.info.id) tcp connection failed")
            case .cancelled:
                self.tcp.status = "cancelled"
                print("\(self.info.ip), \(self.info.id) tcp connection cancelled")
            default:
                self.tcp.status = "unknown"
                print("Unknown status for \(self.info.ip), \(self.info.id)")
            } // switch
        } // stateUpdateHandler
        
        
        // A constant receiver
        self.receiveAndUpdateState()
        
        
    } // Light.init()
    
    
    deinit {
        self.receiverLoop = false
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
            if power == "on" {
                self.state.power = true
            } else {
                self.state.power = false
            }
            
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
            
        default:
            // don't throw error yet - might have more states that will update than anticipated
            print("Property key (\(key)) not handled.  Value is \(value)")
        } // switch
    } // Light.updateState()
    
    
    // decode response received from light and handle them
    private func jsonDecodeAndHandle(_ data: Data?) throws {
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
        
        // Is there data?
        guard let data = data else {
            throw JSONError.noData
        }
        
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
    
    
    // decides on what to do with network errors
    private func receiveErrorHandler(_ error: NWError?, _ earlyReturn:
        (Bool) -> Void) {
        
        if error == NWError.posix(POSIXErrorCode.ECANCELED) {
            
            // if ECANCELED received when not cancelling connection
            // I want to find out if this ever happens for now
            // don't stop receiving
            if self.receiverLoop == true {
                print("Unplanned POSIXErrorCode.ECANCELED")
                print("\(self.info.id) receive error on ip \(self.info.ip):  \(error as Any)")
                // continue without stopping to see if any other issues arise
                earlyReturn(false)
                
            // If the receiver loop is false, ECANCELED is planned
            // stop receiving
            } else {
                self.receiverLoop = false
                earlyReturn(true)
            }
            
        // Print any other errors that arise and don't stop receiving
        } else {
            print("\(self.info.id) receive error on ip \(self.info.ip):  \(error as Any)")
            earlyReturn(false)
        }
    }
    
    
    // handles the receiving from tcp conn with light
    private func receiveAndUpdateState() -> Void {
        self.tcp.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, error) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            
            if error == nil {
                do {
                    // receives tcp messages and handles them
                    try self.jsonDecodeAndHandle(data)
                }
                catch let handlingError {
                    print(handlingError)
                }
                
            } else {
                self.receiveErrorHandler(error, { (earlyReturn) in
                    if earlyReturn == true {
                        return
                    }
                })
                
            }
            
            // recurse
            if self.receiverLoop == true {
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
        
        let sendCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            if NWError != nil {
                print("TCP error in message sent:\n  ID: \(self.info.id)\n  IP: \(self.info.ip)\n  Error: \(NWError as Any)")
            }
        } // let sendCompletion
        
        self.tcp.conn.send(content: requestContent, completion: sendCompletion)
        
    } // Light.communicate()
    
    
    
    
    
} // class Light



