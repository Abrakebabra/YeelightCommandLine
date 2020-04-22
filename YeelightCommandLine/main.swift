//
//  main.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/09.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

var runProgram = true
let controller = Controller()

controller.discover(wait: .lightCount(7))

/*
sleep(2)

for (key, value) in controller.lights {
    print("\(key): ip:\(value.info.ip)")
}
*/

sleep(1)

// test purposes
let bikeLight = controller.lights["0x0000000007e71ffd"]



controller.setLightAlias { (nameTaken) -> String in
    var alias: String = ""
    if nameTaken == true {
        print("Alias name already taken")
    }
    print("Enter name for this light:")
    let rawInput: String? = readLine()
    if let stringAlias = rawInput {
        alias = stringAlias
    }
    return alias
}

for (key, _) in controller.alias {
    print(key)
}


while runProgram == true {
    print("Awaiting input")
    let input: String? = readLine()
    
    switch input {
    case "on":
        do {
            let message = try Method.set_power(power: .on, effect: .sudden).string()
            bikeLight?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "off":
        do {
            let message = try Method.set_power(power: .off, effect: .sudden).string()
            bikeLight?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "ChosenOne":
        do {
            var flowExpressions = Method.set_colorFlow.CreateExpressions()
            try flowExpressions.addState(expression: .rgb(value: 5, bright_val: 100, duration: 5000))
            try flowExpressions.addState(expression: .rgb(value: 30000, bright_val: 100, duration: 2000))
            try flowExpressions.addState(expression: .rgb(value: 160000, bright_val: 100, duration: 4000))
            try flowExpressions.addState(expression: .rgb(value: 300000, bright_val: 100, duration: 3000))
            
            let message = try Method.set_colorFlow(.finite(count: 4), .returnPrevious, flowExpressions).string()
            controller.alias["ChosenOne"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "flow":
        do {
            var flowExpressions = Method.set_colorFlow.CreateExpressions()
            try flowExpressions.addState(expression: .rgb(value: 5, bright_val: 100, duration: 5000))
            try flowExpressions.addState(expression: .rgb(value: 30000, bright_val: 100, duration: 2000))
            try flowExpressions.addState(expression: .rgb(value: 160000, bright_val: 100, duration: 4000))
            try flowExpressions.addState(expression: .rgb(value: 300000, bright_val: 100, duration: 3000))
            
            let message = try Method.set_colorFlow(.finite(count: 8), .returnPrevious, flowExpressions).string()
            bikeLight?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "allOn":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power(power: .on, effect: .sudden, duration: 30).string()
                value.communicate(message)
            }
            catch let error {
                print(error)
            }
        }
        
    case "allOff":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power(power: .off, effect: .sudden, duration: 30).string()
                value.communicate(message)
            }
            catch let error {
                print(error)
            }
        }
    
    case "musicOn":
        do {
            let message = try Method.set_music(light: bikeLight!, state: .on).string()
            bikeLight?.communicate(message)
            
        }
        catch let error {
            print(error)
        }
        
    case "musicOff":
        do {
            let message = try Method.set_music(light: bikeLight!, state: .off).string()
            bikeLight?.communicate(message)
        }
        catch let error {
            print(error)
        }
 
    case "musicTest":
        var hsv = 190
        
        for _ in 0..<100 {
            
            do {
                let message = try Method.set_hsv(hue_value: hsv, sat_value: 50, effect: .sudden).string()
                bikeLight?.communicate(message)
            }
            catch let error {
                print(error)
            }
            usleep(100000)
            hsv -= 2
        }
        
        
    case "discover":
        controller.discover(wait: .lightCount(6))
        
    case "exit":
        for (key, _) in controller.lights {
            controller.lights[key]?.tcp.receiveLoop = false
            controller.lights[key]?.tcp.conn.cancel()
        }
        print("Exiting...")
        sleep(1)
        runProgram = false
        
    default:
        continue
    }
    
}
print("PROGRAM END")


