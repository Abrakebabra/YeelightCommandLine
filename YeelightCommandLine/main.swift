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


controller.discover()


/*
sleep(2)

for (key, value) in controller.lights {
    print("\(key): ip:\(value.info.ip)")
}
*/


while runProgram == true {
    print("Awaiting input")
    let input: String? = readLine()
    
    switch input {
    case "on":
        do {
            let message = try Method.set_power(.on, .sudden).string()
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "off":
        do {
            let message = try Method.set_power(.off, .sudden).string()
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "flow":
        do {
            var flowExpressions = Method.set_colorFlow.CreateExpressions()
            try flowExpressions.addState(.rgb(value: 5, bright_val: 100, duration: 5000))
            try flowExpressions.addState(.rgb(value: 30000, bright_val: 100, duration: 2000))
            try flowExpressions.addState(.rgb(value: 160000, bright_val: 100, duration: 4000))
            try flowExpressions.addState(.rgb(value: 300000, bright_val: 100, duration: 3000))
            
            let message = Method.set_colorFlow(.finite(count: 8), .returnPrevious, flowExpressions).string()
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "allOn":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power(.on, .sudden, 30).string()
                value.communicate(message)
            }
            catch let error {
                print(error)
            }
        }
        
    case "allOff":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power(.off, .sudden, 30).string()
                value.communicate(message)
            }
            catch let error {
                print(error)
            }
        }
    case "exit":
        for (key, _) in controller.lights {
            controller.lights[key]?.receiverLoop = false
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


