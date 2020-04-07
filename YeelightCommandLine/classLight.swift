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
    var rgb: Int  // colorMode 1:  1-16777215 (hex: 0xFFFFFF)
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
    let dispatchGroup: DispatchGroup // Might not use this
    
    
    init(_ ip: String, _ port: String) throws {
        self.ipEndpoint = NWEndpoint.Host(ip)
        guard let portEndpoint = NWEndpoint.Port(port) else {
            throw DiscoveryError.tcpInitFailed("Port not found")
        }
        self.portEndpoint = portEndpoint
        self.conn = NWConnection.init(host: self.ipEndpoint, port: self.portEndpoint, using: .tcp)
        self.status = "unknown"
        self.dispatchQueue = DispatchQueue(label: "tcpConn Queue", attributes: .concurrent)
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
    var requestTicket: Int = 0
    
    enum methodEnum {
        case set_ct_abx
        case set_rgb
        case set_hsv
        case set_bright
        case set_power
        case set_scene
        case set_name
        case adjust_bright
        
        // conversion to string
        var string: String {
            switch self {
            case .set_ct_abx:
                return "set_ct_abx"
            case .set_rgb:
                return "set_rgb"
            case .set_hsv:
                return "set_hsv"
            case .set_bright:
                return "set_bright"
            case .set_power:
                return "set_power"
            case .set_scene:
                return "set_scene"
            case .set_name:
                return "set_name"
            case .adjust_bright:
                return "adjust_bright"
            }
        }
    }
    
    
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
        
        
        
        // SETUP RECEIVE LOOP HERE?
        
        
        
    } // Light.init()
    
    
    // encode commands to required format for light
    fileprivate func jsonEncoder(_ reqID: Int, _ method: methodEnum, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) throws -> Data {
        /*
         JSON COMMANDS
         {"id":1,"method":"set_default","params":[]}
         {"id":1,"method":"set_scene", "params": ["hsv", 300, 70, 100]}
         {"id":1,"method":"get_prop","params":["power", "not_exist", "bright"]}
         */
        
        // different commands have different value types
        var parameters: [Any] = []
        
        // in order, append parameters to array.
        if let param1 = param1 {
            parameters.append(param1)
        }
        if let param2 = param2 {
            parameters.append(param2)
        }
        if let param3 = param3 {
            parameters.append(param3)
        }
        if let param4 = param4 {
            parameters.append(param4)
        }

        let template: String = """
        {"id":\(reqID), "method":\(method.string), "params":\(parameters)}\r\n
        """
        
        guard let request: Data = template.data(using: .utf8) else {
            throw RequestError.stringToData
        }
        
        return request
    }  // jsonEncoder
    
    
    
    fileprivate func updateState(_ key: String, _ value: Any) throws {
        switch key {
        case "power":
            guard let power = value as? String else {
                throw LightStateUpdateError.param1("power to String failed")
            }
            if power == "on" {
                self.state.power = true
            } else {
                self.state.power = false
            }
        case "bright":
            guard let brightness = value as? Int else {
                throw LightStateUpdateError.param1("brightness to Int failed")
            }
            self.state.brightness = brightness
        case "color_mode":
            guard let colorMode = value as? Int else {
                //throw LightStateUpdateError.param2("colorTemp to Int failed")
            }
            self.state.colorMode = colorMode
        case "ct":
            guard let colorTemp = value as? Int else {
                //throw LightStateUpdateError.param2("colorTemp to Int failed")
            }
            self.state.colorTemp = colorTemp
        case "rgb":
            //
        case "hue":
            //
        case "sat":
            //
        case "name":
            //
        default:
            print("Property \(key) not handled")
        }
    }
    
    
    
    
    
    // decode response received from light
    fileprivate func jsonDecoder(Response data: Data?) throws -> (Int, [String]) {
        /*
         JSON RESPONSES
         
         Standard Responses     [String]
         {"id":1, "result":["ok"]}
         get_pro Response       [String]
         {"id":1, "result":["on", "", "100"]}
         
         Error Response
         {"id":2, "error":{"code":-1, “message”:"unsupported method"}}
         [String:[String:Any]]
         
         UNUSED:
         cron_get Response      [[String:Int]]
         {"id":1, "result":[{"type": 0, "delay": 15, "mix": 0}]}
         Won't use this response.
         cron methods can only turn off light after X minutes.  No need for a timer function.
         
         Secondary response:
         {"method":"props","params":{"ct":6500}}
         */
        
        
        /*
         NEW PLAN:
         Is there "id"?
         yes - Handle responses or errors
         no:
         Is there "method"?
         yes - handle method
         no - invalid response - print?
 
        */
        
        
        // Deserialize the data to a JSON object
        // Inspect contents of JSON object and look for "result" (ignore "id")
        // If no "result" found, look for "error"
        // Find error code and error message and throw error details
        // If error code and message not found, throw error on error object
        // If no "error" found, throw unknown error
        
        
        // Is there data?
        guard let data = data else {
            throw JSONError.noData
        }
        
        // jsonserialization object
        let deserializer = try JSONSerialization.jsonObject(with: data, options: [])
        
        // unpack the top level json object
        guard let jsonObject = deserializer as? [String:Any] else {
            throw JSONError.jsonObject
        }
        
        // does top level object have "id"?
        // if not, does top level object have "method"?
        // if not, throw an error
        
        // results
        if let resultList = jsonObject["result"] as? [String] {
            if let id = jsonObject["id"] as? Int {
                // if there is a resultList
                print("id \(id): \(resultList)")
            } else {
                print("No id: \(resultList)")
            }
            
        // errors
        } else if let error = jsonObject["error"] as? [String:Any] {
            guard
                let errorCode: String = error["code"] as? String,
                let errorMessage: String = error["message"] as? String
                else {
                    // if can't unpack error object
                    throw JSONError.errorObject
            }
            
            if let id = jsonObject["id"] as? Int {
                throw JSONError.response("id: \(id)  Error Code \(errorCode): \(errorMessage)")
            } else {
                throw JSONError.response("Error Code \(errorCode): \(errorMessage)")
            }
        
        // change in state
        } else if let method = jsonObject["method"] as? String {
            guard let changedStates =
                jsonObject["params"] as? [String:Any] else {
                    throw JSONError.params
            }
            
            for (key, value) in changedStates {
                // switch function for updating state
            }
            
            
        } else {
            throw JSONError.unknown(jsonObject)
        }
        
        
        
        
        
        
       
    } // jsonDecode
    
    
    
    
    
    
    
    
    
    
    // NO LONGER REQUIRED?
    // updates the state if response from light is "ok"
    fileprivate func OLDupdateState(_ method: methodEnum, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) throws {
        
        switch method {
        case .set_ct_abx:
            
            guard let colorTemp = param1 as? Int else {
                throw LightStateUpdateError.param1("colorTemp to Int failed")
            }
            self.state.colorTemp = colorTemp
            self.state.colorMode = 2
            
        case .set_rgb:
            
            guard let rgb = param1 as? Int else {
                throw LightStateUpdateError.param1("rgb to Int failed")
            }
            self.state.rgb = rgb
            self.state.colorMode = 1
            
        case .set_hsv:
            
            guard let hue = param1 as? Int else {
                throw LightStateUpdateError.param1("hue to Int failed")
            }
            self.state.hue = hue
            
            guard let sat = param2 as? Int else {
                throw LightStateUpdateError.param2("sat to Int failed")
            }
            self.state.sat = sat
            self.state.colorMode = 3
            
        case .set_bright:
            
            guard let brightness = param1 as? Int else {
                throw LightStateUpdateError.param1("brightness to Int failed")
            }
            self.state.brightness = brightness
            
        case .set_power:
            
            guard let power = param1 as? String else {
                throw LightStateUpdateError.param1("power to String failed")
            }
            if power == "on" {
                self.state.power = true
            } else {
                self.state.power = false
            }
            
        case .set_scene:
            
            // action trying to change rgb, ct or hsv
            guard let action = param1 as? String else {
                throw LightStateUpdateError.param1("set_scene to String failed")
            }
            
            switch action {
            case "color":
                guard let rgb = param2 as? Int else {
                    throw LightStateUpdateError.param2("rgb to Int failed")
                }
                self.state.rgb = rgb
                self.state.colorMode = 1
                
                guard let brightness = param3 as? Int else {
                    throw LightStateUpdateError.param3("brightness to Int failed")
                }
                self.state.brightness = brightness
                
            case "ct":
                guard let colorTemp = param2 as? Int else {
                    throw LightStateUpdateError.param2("colorTemp to Int failed")
                }
                self.state.colorTemp = colorTemp
                self.state.colorMode = 2
                
                guard let brightness = param3 as? Int else {
                    throw LightStateUpdateError.param3("brightness to Int failed")
                }
                self.state.brightness = brightness
                
            case "hsv":
                guard let hue = param2 as? Int else {
                    throw LightStateUpdateError.param2("hue to Int failed")
                }
                self.state.hue = hue
                
                guard let sat = param3 as? Int else {
                    throw LightStateUpdateError.param3("sat to Int failed")
                }
                self.state.sat = sat
                self.state.colorMode = 3
                
                guard let brightness = param4 as? Int else {
                    throw LightStateUpdateError.param4("brightness to Int failed")
                }
                self.state.brightness = brightness
                
            default:
                throw LightStateUpdateError.param1("Action not color, ct or hsv")
            }
            
        case .set_name:
            
            guard let name = param1 as? String else {
                throw LightStateUpdateError.param1("name to Int failed")
            }
            self.name = name
            
        case .adjust_bright:
            
            guard let change = param1 as? Int else {
                throw LightStateUpdateError.param1("adjust_bright to Int failed")
            }
            let newValue = self.state.brightness + change
            if newValue < 1 {
                self.state.brightness = 1
            } else if newValue > 100 {
                self.state.brightness = 100
            } else {
                self.state.brightness = newValue
            }
            
        } // switch method
    } // updateState
    
    
    // NOT COMPLETE
    fileprivate func receiveAndUpdateState(_ method: methodEnum, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) {
        self.tcp.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, _, NWError) in
            // Data?, NWConnection.ContentContext?, Bool, NWError?
            if NWError != nil {
                print(NWError as Any)
                return
            }
            
            do {
                let response: (Int, [String]) = try self.jsonDecoder(Response: data)
                // handle "ok" response
                // handle get_prop response
                // handle error response
                if response.1[0] == "ok" {
                    try self.updateState(method, param1, param2, param3, param4)
                } else if ...
                
                
            }
            catch let error {
                print(error)
            }
            
            
            
        } // conn.receive
    } // receiver function
    
    
    // Send a command to the light
    func communicate(method: methodEnum, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) throws {
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
        
        let requestContent: Data = try jsonEncoder(self.requestTicket, method, param1, param2, param3, param4)
        
        
        let sendCompletion = NWConnection.SendCompletion.contentProcessed { (NWError) in
            if NWError != nil {
                print("TCP error in message sent:\n  ID: \(self.id)\n  IP: \(self.ip)\n  Error: \(NWError as Any)")
                
            } else {
                // NOT REQUIRED IF CONSTANT LOOP IS RUNNING IN INIT()
                self.receiveAndUpdateState(method, param1, param2, param3, param4)
            }
        } // sendCompletion
        
        self.tcp.conn.send(content: requestContent, completion: sendCompletion)
        
    } // communicate
    
    
    
    
    
} // class Light


