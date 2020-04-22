//
//  structMethod.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/04/12.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation
import Network // for set_music listener

// ==========================================================================
// CONTENTS =================================================================
// ==========================================================================

// public enum Enums
    // public enum Effect
    // public enum PowerState
    // public enum numOfStateChanges
    // public enum onCompletion
    // public enum setState

// public struct Method
    // various methods


/// Enumerators for Method structs
public enum Enums {
    
    /// gradual or instant change
    public enum Effect {
        case sudden
        case smooth
        
        public func string() -> String {
            switch self {
            case .sudden:
                return "sudden"
            case .smooth:
                return "smooth"
            }
        }
    }
    
    /// on or off
    public enum OnOff {
        case on
        case off
        
        public func string() -> String {
            switch self {
            case .on:
                return "on"
            case .off:
                return "off"
            }
        }
    }
    
    
    // start_cf
    // don't forget to add a check later to ensure that the number of state changes are at least equal to the number of states added
    /// How many state changes
    public enum numOfStateChanges {
        case infinite
        case finite(count: Int)
        
        public func int() -> Int {
            switch self {
            case .infinite:
                return 0
                
            /// how many state changes - must be equal or higher than number of states.
            case .finite(let count):
                return count
            }
        }
    } // enum numOfStateChanges
    
    // start_cf
    public enum onCompletion {
        case returnPrevious
        case stayCurrent
        case turnOff
        
        public func int() -> Int {
            switch self {
                
            /// return to previous setting
            case .returnPrevious:
                return 0
                
            /// finish flow and remain on that setting
            case .stayCurrent:
                return 1
            
            case .turnOff:
                return 2
            }
        }
    } // enum onCompletion
    
    // start_cf
    // creates a tuple for each color state
    public enum setState {
        case rgb(value: Int, bright_val: Int, duration: Int)
        case color_temp(value: Int, bright_val: Int, duration: Int)
        case wait(duration: Int)
        
        // returns [duration, mode, rgb or color_temp val, bright_val]
        // min duration here is 50ms as opposed to 30 elsewhere
        public func params() throws -> [Int] {
            switch self {
                
            /// rgb range: 1-16777215, color_temp range: 1700-6500, brightness range: 1-100, duration min = 50ms (as default).  No hsv mode.
            case .rgb(let value, let bright_val, let duration):
                try Method().valueInRange("rgb_value", value, min: 1, max: 16777215)
                try Method().valueInRange("bright_val", bright_val, min: 1, max: 100)
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 1, value, bright_val]
                
            /// color_temp range: 1700-6500, brightness range: 1-100, duration min = 50ms (as default)
            case .color_temp(let value, let bright_val, let duration):
                try Method().valueInRange("color_temp", value, min: 1700, max: 6500)
                try Method().valueInRange("bright_val", bright_val, min: 1, max: 100)
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 2, value, bright_val]
                
            /// duration min = 50ms (as default)
            case .wait(let duration):
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 7, 0, 0]
            }
        }
    } // enum setState
} // enum Enums




// A rigid structure to ensure that all methods and parameters to be sent to the light as a command meet the light's rules to eliminate typos.
public struct Method {
    
    //"effect" support two values: "sudden" and "smooth". If effect is "sudden", then the color temperature will be changed directly to target value, under this case, the third parameter "duration" is ignored. If effect is "smooth", then the color temperature will be changed to target value in a gradual fashion, under this case, the total time of gradual change is specified in third parameter "duration".
    //"duration" specifies the total time of the gradual changing. The unit is milliseconds. The minimum support duration is 30 milliseconds.
    
    // encode commands to required format for light
    private func methodParamString(_ method: String, _ param1: Any? = nil, _ param2: Any? = nil, _ param3: Any? = nil, _ param4: Any? = nil) -> String {
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
        
        return """
        "method":"\(method)", "params":\(parameters)
        """
    } // Method.methodParamString()
    
    
    // checks that a range is within the bounds per specifications
    fileprivate func valueInRange(_ valueName: String, _ value: Int, min: Int, max: Int? = nil) throws -> Void {
        
        guard value >= min else {
            throw MethodError.valueBeyondMin("\(valueName) below minimum inclusive of \(min)")
        }
        
        if max != nil {
            guard value <= max! else {
                throw MethodError.valueBeyondMax("\(valueName) above maximum inclusive of \(max!)")
            }
        }
    } // Method.valueBoundCheck()
    
    
    // no get_prop method
    
    
    public struct set_colorTemp {
        private let method: String = "set_ct_abx"
        private let p1_ct_value: Int
        private let p2_effect: String
        private let p3_duration: Int
        
        /// temp range: 1700-6500, duration min = 30ms (as default)
        init(color_temp: Int, effect: Enums.Effect, duration: Int = 30) throws {
            try Method().valueInRange("color_temp", color_temp, min: 1700, max: 6500)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_ct_value = color_temp
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_ct_value, self.p2_effect, self.p3_duration)
        }
    } // Method.set_colorTemp
    
    
    public struct set_rgb {
        private let method = "set_rgb"
        private let p1_rgb_value: Int
        private let p2_effect: String
        private let p3_duration: Int
        
        /// rgb range: 1-16777215, duration min = 30ms (as default)
        init(rgb_value: Int, effect: Enums.Effect, duration: Int = 30) throws {
            try Method().valueInRange("rgb_value", rgb_value, min: 1, max: 16777215)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_rgb_value = rgb_value
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_rgb_value, self.p2_effect, self.p3_duration)
        }
    } // Method.set_rgb
    
    
    public struct set_hsv {
        private let method: String = "set_hsv"
        private let p1_hue_value: Int
        private let p2_sat_value: Int
        private let p3_effect: String
        private let p4_duration: Int
        
        /// hue range: 0-359, sat range: 0-100, duration min = 30ms (as default)
        init(hue_value: Int, sat_value: Int, effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("hue_value", hue_value, min: 0, max: 359)
            try Method().valueInRange("sat_value", sat_value, min: 0, max: 100)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_hue_value = hue_value
            self.p2_sat_value = sat_value
            self.p3_effect = effect.string()
            self.p4_duration = duration
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_hue_value, self.p2_sat_value, self.p3_effect, self.p4_duration)
        }
    } // Method.set_hsv
    
    
    public struct set_bright {
        private let method: String = "set_bright"
        private let p1_bright_value: Int
        private let p2_effect: String
        private let p3_duration: Int
        
        /// brightness range: 1-100, duration min = 30ms (as default)
        init(bright_value: Int, effect: Enums.Effect, duration: Int = 30) throws {
            try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_bright_value = bright_value
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_bright_value, self.p2_effect, self.p3_duration)
        }
    } // Method.set_bright
    
    
    public struct set_power {
        private let method: String = "set_power"
        private let p1_power: String
        private let p2_effect: String
        private let p3_duration: Int
        // has optional 4th parameter to switch to mode but excluding
        
        /// duration min = 30ms (as default)
        init(power: Enums.OnOff, effect: Enums.Effect, duration: Int = 30) throws {
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_power = power.string()
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_power, self.p2_effect, self.p3_duration)
        }
    } // Method.set_power
    
    
    // no toggle method
    // no set_default method
    
    
    public struct set_colorFlow {
        
        /// create a saved array holding all added states.  addState() subsequently to append to array. This object is passed directly as a parameter to set_colorFlow.init()
        public struct CreateExpressions {
            private var allExpressions: [Int] = []
            
            /// append a new flow state to the CreateExpressions array.  rgb range: 1-16777215, color_temp range: 1700-6500, hue range: 0-359, sat range: 0-100, brightness range: 1-100, duration min = 30ms (as default)
            public mutating func addState(expression: Enums.setState) throws {
                try self.allExpressions.append(contentsOf: expression.params())
                
            }
            
            // output this to a clean string "1, 2, 3, 4" with no square parenthesis
            fileprivate func output() -> (Int, String) {
                var tupleString: String = ""
                
                for i in self.allExpressions {
                    
                    if tupleString.count < 1 {
                        tupleString.append(contentsOf: String(i))
                    } else {
                        tupleString.append(contentsOf: ", \(String(i))")
                    }
                }
                
                // Each state has 4 values.  Returns number of states.
                // Enums.setState will only pass through 4 digits each time
                return (self.allExpressions.count / 4, tupleString)
            }
        }
        
        
        // {"id":1, "method":"start_cf", "params":[4, 2, "1000,2,2700,100"]}
        
        private let method: String = "start_cf"
        private let p1_count: Int
        private let p2_action: Int
        private let p3_flow_expression: String // custom type to ensure correct usage?
        
        /// CreateExpressions object required with subsequent addState().  Number of state changes must be equal or higher than number of state changes.
        init(_ change_count: Enums.numOfStateChanges, _ onCompletion: Enums.onCompletion, _ flow_expression: Method.set_colorFlow.CreateExpressions) throws {
            
            let expressions: (Int, String) = flow_expression.output()
            let expressionCount: Int = expressions.0
            self.p1_count = change_count.int()
            self.p2_action = onCompletion.int()
            self.p3_flow_expression = expressions.1
            
            guard self.p1_count >= expressionCount else {
                throw MethodError.fewerChangesThanStatesEntered
            }
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(method, p1_count, p2_action, p3_flow_expression)
        }
    } // Method.set_colorFlow
    
    
    /// cancel current color flow
    public struct set_colorFlowStop {
        private let method: String = "stop_cf"
        
        /// takes no parameters.
        init(_ takesNoParametersLeaveEmpty: Any? = nil) {
            // Takes an empty array.
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method)
        }
    } // Method.set_colorFlowStop
    
    
    /// send both rgb, hsv or colorTemp change along with brightness in a single command
    public struct set_scene {
        // leaving out color flow because it doesn't benefit from having an additional method through set_scene whereas rgb and ct can adjust brightness in a single command rather than separately.
        // Might review color flow in the future (10 April 2020).
        
        public struct rgb_bright {
            private let method: String = "set_scene"
            private let p1_method: String = "color"
            private let p2_rgb: Int
            private let p3_bright: Int
            
            /// rgb range: 1-16777215, brightness range: 1-100
            init(_ rgb_value: Int, _ bright_value: Int) throws {
                try Method().valueInRange("rgb_value", rgb_value, min: 1, max: 16777215)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_rgb = rgb_value
                self.p3_bright = bright_value
            }
            
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_rgb, self.p3_bright)
            }
        } // Method.set_scene.rgb_bright
        
        public struct hsv_bright {
            private let method: String = "set_scene"
            private let p1_method: String = "hsv"
            private let p2_hue: Int
            private let p3_sat: Int
            private let p4_bright: Int
            
            /// hue range: 0-359, sat range: 0-100, brightness range: 1-100
            init(_ hue_value: Int, _ sat_value: Int, _ bright_value: Int) throws {
                try Method().valueInRange("hue_value", hue_value, min: 0, max: 359)
                try Method().valueInRange("sat_value", sat_value, min: 0, max: 100)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_hue = hue_value
                self.p3_sat = sat_value
                self.p4_bright = bright_value
            }
            
            /// output as string in correct format for the light
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_hue, self.p3_sat, self.p4_bright)
            }
        } // Method.set_scene.hsv_bright
        
        public struct color_temp_bright {
            private let method: String = "set_scene"
            private let p1_method: String = "ct"
            private let p2_color_temp: Int
            private let p3_bright: Int
            
            /// color_temp range: 1700-6500, brightness range: 1-100
            init(_ color_temp: Int, _ bright_value: Int) throws {
                try Method().valueInRange("color_temp", color_temp, min: 1700, max: 6500)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_color_temp = color_temp
                self.p3_bright = bright_value
            }
            
            /// output as string in correct format for the light
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_color_temp, self.p3_bright)
            }
        } // Method.set_scene.color_temp_bright
    } // Method.set_scene
    
    
    // no cron_add method
    // no cron_get method
    // no cron_del method
    // no set_adjust method
    
    
    /// new TCP connection with unlimited commands and no property update response
    public class set_music {
        /*
         "action" the action of set_music command. The valid value can be:
            0: turn off music mode.
            1: turn on music mode.
         "host" the IP address of the music server.
         "port" the TCP port music application is listening on.
         
         Request:
         {"id":1,"method":"set_music","params":[1, “192.168.0.2", 54321]}
         {"id":1,"method":"set_music","params":[0]}
         
         Response:
         {"id":1, "result":["ok"]}
         
         When control device wants to start music mode:
          - it needs start a TCP server firstly
          - then call “set_music” command to let the device know the IP and Port of the TCP listen socket.
          - After received the command, LED device will try to connect the specified peer address.
          - control device should then send all supported commands through this channel without limit to simulate any music effect.
          - The control device can stop music mode by explicitly send a stop command or just by closing the socket.
         
         TO DO:
         Build method for sending params
         Build listener and handlers
         
          - Set up listener, start and just use listener.port after it starts
          - save that port - use an escaping closure
          - send message to light notifying local ip and listener port (add IP to existing function)
          - save that one new connection
          - create new tcp connection instance with that
        */
        
        
        /*
         FUNCTION'S CONTROL FLOW EXPLAINED
         (Weds April 22, 2020, 2:02am) because I didn't document it the first time, because I finished it the day before at 3:30am and went straight to bed.
         
         Each step is copied and pasted into the appropriate location within this class.
         
         Step 1:  Class instance in Thread A (calling thread) is created
            let message = try Method.set_music(light: light, state: .on).string()
         
         Step 2:  self.p1_action and self.p2_listenerHost are initalised
         
         Step 3:  Listener function is called asynchonously and runs in its own Thread B.
         
         Step 4:  The listener function has an escaping closure (listener port escaping) that will be called when the listener's status is ready.
         
         Step 5:  init is now waiting at end of closure before completion, blocking the calling thread (Thread A).  LOCK 1. *(See appendix for timeout details)
         
         Step 6:  Listener is now waiting at end of closure before completion (LOCK 2), on a timeout of 1 second if target IP is not found, which will cancel the listener.
         
         Step 7:  Once listener state is ready, it passes the port it selected to the escaping closure which sets self.p3_listenerPort and RELEASE LOCK 1.
         
         Step 8:  Initialiser is now complete.  The string is sent to the light. (listener still waiting in Thread B).
         
         Step 9:  The light receives the message and now attempts to connect to the listener's IP and Port.
         
         Step 10:  Listener finds the light, checks its IP against the light it was targetting.  If the IP found does not match, it will ignore.  If the IP matches, it will create a new Connection instance and save it directly to the Light instance passed to this Struct.  If found, it will immediately RELEASE LOCK 2 in the listener.
         
         Step 11:  Listener is cancelled and function is now complete.
         
         * Appendix:  If the listener times out, the listener port is nil and the self.string() function filters the nil value out.  Method, p1 and p2 are passed to the Light.communicate() function which sends this to the light.  The command is missing port and the light rejects this as invalid and ignores it with no response.
         
        */
        private let method: String = "set_music"
        private let p1_action: Int
        private var p2_listenerHost: String?
        private var p3_listenerPort: Int?
        
        private var listener: NWListener?
        private let targetLight: Light
        private let controlQueue = DispatchQueue(label: "Control Queue")
        private let controlGroup = DispatchGroup()
        
        
        
        /// closure(listenerPort: Int)
        func listen(_ closure:@escaping (Int) -> Void) throws -> Void {
            
            // ... step 3 continues asynchronously... to step 6 below
            
            // control flow for function
            let listenerGroup = DispatchGroup()
            // queue
            let serialQueue = DispatchQueue(label: "TCP Queue")
            // setup listener in class to be cancelled via another function
            self.listener = try? NWListener(using: .tcp)
            // was listener successfully set up?
            guard let listener = self.listener else {
                throw ListenerError.listenerFailed
            }
            
            
            listener.newConnectionHandler = { (newConn) in
                
                // STEP 9:  The light receives the message and now attempts to connect to the listener's IP and Port.
                
                if let remoteEnd = newConn.currentPath?.remoteEndpoint,
                    let targetIP = self.targetLight.tcp.remoteHost {
                    
                    switch remoteEnd {
                    case .hostPort(let host, let port):
                        
                        if host == targetIP {
                            
                            // STEP 10:  Listener finds the light, checks its IP against the light it was targetting.  If the IP found does not match, it will ignore.  If the IP matches, it will create a new Connection instance and save it directly to the Light instance passed to this Struct.  If found, it will immediately RELEASE LOCK 2 in the listener.
                            
                            self.targetLight.musicModeTCP = Connection(existingConn: newConn, existingQueue: serialQueue, remoteHost: host, remotePort: port, receiveLoop: false)
                            listenerGroup.leave()
                        } // if new connection IP and target IP match
                        
                    default:
                        return
                    } // switch statement
                } // remote end and target IP unwrapped
            } // listener
            
            
            listener.stateUpdateHandler = { (newState) in
                switch newState {
                case .ready:
                    
                    // STEP 7:  Once listener state is ready, it passes the port it selected to the escaping closure which sets self.p3_listenerPort and RELEASE LOCK 1.
                    
                    // get port and allow it to be accessed in closure to be used as parameter in command to light
                    if let listenerPort = listener.port?.rawValue {
                        closure(Int(listenerPort))
                    }
                case .failed(let error):
                    print("listener failed error: \(error)")
                default:
                    return
                }
            }
            
            
            listenerGroup.enter()
            listener.start(queue: serialQueue)
            
            // length of time to wait until
            let waitTime: UInt64 = 1 // default timeout seconds
            let futureTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + waitTime * 1000000000)
            
            // STEP 6:  Listener is now waiting at end of closure before completion (LOCK 2), on a timeout of 1 second if target IP is not found, which will cancel the listener, and TIMEOUT RELEASE LOCK 1. *(See appendix for details)
            
            // wait 1 second to establish music TCP.  If not found, cancel listener.
            if listenerGroup.wait(timeout: futureTime) == .timedOut {
                print("Listener: No connection available for music TCP")
                listener.cancel()
                listenerGroup.leave()
                throw ListenerError.noConnectionFound
            }
            
            // STEP 11:  Listener is cancelled and entire function is now complete.
            
            // on success
            listener.cancel()
        } // Method.set_music.listen()
        
        
        /// light: target light to affect, and simple .on or .off.  Off instances will cancel the musicTCP connection, and upon cancellation will deinit the Connection instance.
        init(light: Light, state: Enums.OnOff) throws {
            
            //  STEP 1:  instance in Thread A (calling thread) is created
            
            self.targetLight = light // save reference to target light
            
            switch state {
            case .on:
                
                if let mode = self.targetLight.state.musicMode {
                    if mode == true {
                        print("Already an existing music TCP connection")
                        throw ConnectionError.connectionNotMade
                    }
                }
                
                self.p1_action = 1
                
                // find the local IP
                guard let localEndpoint = self.targetLight.tcp.getHostPort(endpoint: .local) else {
                    throw ConnectionError.endpointNotFound
                }
                
                // local IP is listener IP to send to light
                self.p2_listenerHost = String(reflecting: localEndpoint.0)
                
                // STEP 2:  self.p1_action and self.p2_listenerHost are initalised
                
                self.controlGroup.enter()
                
                // STEP 3:  Listener function is called asynchonously and runs in its own Thread B.
                self.controlQueue.async {
                    do {
                        try self.listen() {
                            (port) in
                            // STEP 4:  The listener function has an escaping closure (listener port escaping) that will be called when the listener's status is ready.
                            self.p3_listenerPort = port
                            print("listener port found")
                            self.controlGroup.leave() // control unlock
                        }
                    }
                    catch let error {
                        print(error)
                    }
                } // controlQueue.async
                
            case .off:
                self.p1_action = 0
                // connection cancel and deinit is handled by Light class.
            } // switch
            
            // STEP 5:  init is now waiting at end of closure before completion, blocking the calling thread (Thread A).  LOCK 1. Next step in listen().
            
            // length of time to wait until
            let futureTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 500000000) // 0.5s
            if self.controlGroup.wait(timeout: futureTime) == .timedOut {
                print("listener failed to set up and establish port")
            } // control lock
            
            // Step 8:  Initialiser is now complete.  The string is sent to the light. (listener still waiting in Thread B).  Next step in listener newConn handler.
            
        } // Method.set_music.init()
        
        
        /// output as string in correct format for the light
        public func string() -> String {
            // the listener with a DispatchGroup lock should stop the init from returning before it finds the
            return Method().methodParamString(self.method, self.p1_action, self.p2_listenerHost, self.p3_listenerPort)
        }
        
    } // Method.set_music
    
    
    public struct set_name {
        private let method: String = "set_name"
        private let p1_name: String
        
        init(_ name: String) {
            self.p1_name = name
        }
        
        /// output as string in correct format for the light
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_name)
        }
    } // Method.set_name
    
    // no bg_set_xxx / bg_toggle method
    // no dev_toggle method
    // no adjust_bright method
    // no adjust_ct method
    // no adjust_color method
    // no bg_adjust_xx method
    
    
} // struct Method
