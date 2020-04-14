//
//  structMethod.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/04/12.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

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
    
    /// power on or off
    public enum PowerState {
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
            case .finite(let count):
                return count
            }
        }
    }
    
    // start_cf
    public enum onCompletion {
        case returnPrevious
        case stayCurrent
        case turnOff
        
        public func int() -> Int {
            switch self {
            case .returnPrevious:
                return 0
            case .stayCurrent:
                return 1
            case .turnOff:
                return 2
            }
        }
    }
    
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
                
            case .rgb(let value, let bright_val, let duration):
                try Method().valueInRange("rgb_value", value, min: 1, max: 16777215)
                try Method().valueInRange("bright_val", bright_val, min: 1, max: 100)
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 1, value, bright_val]
                
            case .color_temp(let value, let bright_val, let duration):
                try Method().valueInRange("color_temp", value, min: 1700, max: 6500)
                try Method().valueInRange("bright_val", bright_val, min: 1, max: 100)
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 2, value, bright_val]
                
            case .wait(let duration):
                try Method().valueInRange("duration", duration, min: 50)
                return [duration, 7, 0, 0]
            }
        }
    }
}




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
    }
    
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
        public let method: String = "set_ct_abx"
        public let p1_ct_value: Int
        public let p2_effect: String
        public let p3_duration: Int
        
        init(_ color_temp: Int, _ effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("color_temp", color_temp, min: 1700, max: 6500)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_ct_value = color_temp
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_ct_value, self.p2_effect, self.p3_duration)
        }
    }
    
    
    public struct set_rgb {
        public let method = "set_rgb"
        public let p1_rgb_value: Int
        public let p2_effect: String
        public let p3_duration: Int
        
        init(_ rgb_value: Int, _ effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("rgb_value", rgb_value, min: 1, max: 16777215)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_rgb_value = rgb_value
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_rgb_value, self.p2_effect, self.p3_duration)
        }
    }
    
    public struct set_hsv {
        public let method: String = "set_hsv"
        public let p1_hue_value: Int
        public let p2_sat_value: Int
        public let p3_effect: String
        public let p4_duration: Int
        
        init(_ hue_value: Int, sat_value: Int, _ effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("hue_value", hue_value, min: 0, max: 359)
            try Method().valueInRange("sat_value", sat_value, min: 0, max: 100)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_hue_value = hue_value
            self.p2_sat_value = sat_value
            self.p3_effect = effect.string()
            self.p4_duration = duration
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_hue_value, self.p2_sat_value, self.p3_effect, self.p4_duration)
        }
    }
    
    public struct set_bright {
        public let method: String = "set_bright"
        public let p1_bright_value: Int
        public let p2_effect: String
        public let p3_duration: Int
        
        init(_ bright_value: Int, _ effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_bright_value = bright_value
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_bright_value, self.p2_effect, self.p3_duration)
        }
    }
    
    public struct set_power {
        public let method: String = "set_power"
        public let p1_power: String
        public let p2_effect: String
        public let p3_duration: Int
        // has optional 4th parameter to switch to mode but excluding
        
        
        init(_ power: Enums.PowerState, _ effect: Enums.Effect, _ duration: Int = 30) throws {
            try Method().valueInRange("duration", duration, min: 30)
            self.p1_power = power.string()
            self.p2_effect = effect.string()
            self.p3_duration = duration
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_power, self.p2_effect, self.p3_duration)
        }
    }
    
    // no toggle method
    // no set_default method
    
    public struct set_colorFlow {
        
        public struct CreateExpressions {
            public var allExpressions: [Int]
            
            init() {
                self.allExpressions = []
            }
            
            // check what mutating does
            public mutating func addState(_ expression: Enums.setState) throws {
                try self.allExpressions.append(contentsOf: expression.params())
                
            }
            
            fileprivate func output() -> (Int, String) {
                // output this to a clean string "1, 2, 3, 4, 5" with no square parenthesis
                
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
        
        public let method: String = "start_cf"
        public let p1_count: Int
        public let p2_action: Int
        public let p3_flow_expression: String // custom type to ensure correct usage?
        
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
        
        public func string() -> String {
            return Method().methodParamString(method, p1_count, p2_action, p3_flow_expression)
        }
    }
    
    public struct set_colorFlowStop {
        public let method: String = "stop_cf"
        
        init(_ takesNoParametersLeaveEmpty: Any? = nil) {
            // Takes an empty array.
        }
        public func string() -> String {
            return Method().methodParamString(self.method)
        }
    }
    
    
    public struct set_scene {
        // leaving out color flow because it doesn't benefit from having an additional method through set_scene whereas rgb, hsv and ct can adjust brightness in a single command rather than separately.
        // Might review color flow in the future (10 April 2020).
        
        public struct rgb_bright {
            public let method: String = "set_scene"
            public let p1_method: String = "color"
            public let p2_rgb: Int
            public let p3_bright: Int
            
            init(_ rgb_value: Int, _ bright_value: Int) throws {
                try Method().valueInRange("rgb_value", rgb_value, min: 1, max: 16777215)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_rgb = rgb_value
                self.p3_bright = bright_value
            }
            
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_rgb, self.p3_bright)
            }
        }
        
        public struct hsv_bright {
            public let method: String = "set_scene"
            public let p1_method: String = "hsv"
            public let p2_hue: Int
            public let p3_sat: Int
            public let p4_bright: Int
            
            init(_ hue_value: Int, _ sat_value: Int, _ bright_value: Int) throws {
                try Method().valueInRange("hue_value", hue_value, min: 0, max: 359)
                try Method().valueInRange("sat_value", sat_value, min: 0, max: 100)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_hue = hue_value
                self.p3_sat = sat_value
                self.p4_bright = bright_value
            }
            
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_hue, self.p3_sat, self.p4_bright)
            }
        }
        
        public struct color_temp_bright {
            public let method: String = "set_scene"
            public let p1_method: String = "ct"
            public let p2_color_temp: Int
            public let p3_bright: Int
            
            init(_ color_temp: Int, _ bright_value: Int) throws {
                try Method().valueInRange("color_temp", color_temp, min: 1700, max: 6500)
                try Method().valueInRange("bright_value", bright_value, min: 1, max: 100)
                self.p2_color_temp = color_temp
                self.p3_bright = bright_value
            }
            
            public func string() -> String {
                return Method().methodParamString(self.method, self.p1_method, self.p2_color_temp, self.p3_bright)
            }
        }
    }
    
    // no cron_add method
    // no cron_get method
    // no cron_del method
    // no set_adjust method
    
    public struct set_music {
        
        
    }
    
    
    public struct set_name {
        public let method: String = "set_name"
        public let p1_name: String
        
        init(_ name: String) {
            self.p1_name = name
        }
        
        public func string() -> String {
            return Method().methodParamString(self.method, self.p1_name)
        }
    }
    
    // no bg_set_xxx / bg_toggle method
    // no dev_toggle method
    // no adjust_bright method
    // no adjust_ct method
    // no adjust_color method
    // no bg_adjust_xx method
    
    
} // struct Method
