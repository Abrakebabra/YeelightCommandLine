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


controller.discover(wait: .lightCount(6))

/*
sleep(2)

for (key, value) in controller.lights {
    print("\(key): ip:\(value.info.ip)")
}
*/

sleep(1)

while runProgram == true {
    print("Awaiting input")
    let input: String? = readLine()
    
    switch input {
    case "on":
        do {
            let message = try Method.set_power(power: .on, effect: .sudden).string()
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "off":
        do {
            let message = try Method.set_power(power: .off, effect: .sudden).string()
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
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
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
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
            let localEndpoint = controller.lights["0x0000000007e71ffd"]?.tcp.getHostPort(endpoint: .local)
            let targetIP = controller.lights["0x0000000007e71ffd"]?.tcp.remoteHost
            
            if let localEndpoint = localEndpoint, let targetIP = targetIP {
                let musicMode = try Method.set_music(turn: .on, ownIP: localEndpoint.0, targetIP: targetIP)
                let message = try musicMode.string()
                
                controller.lights["0x0000000007e71ffd"]?.communicate(message)
                
                controller.lights["0x0000000007e71ffd"]?.musicModeTCP =
                    try musicMode.savedConnection()
                controller.lights["0x0000000007e71ffd"]?.state.musicMode = true
            }
            
        }
        catch let error {
            print(error)
        }
        
    case "musicOff":
        do {
            let localEndpoint = controller.lights["0x0000000007e71ffd"]?.tcp.getHostPort(endpoint: .local)
            let targetIP = controller.lights["0x0000000007e71ffd"]?.tcp.remoteHost
            
            if let localEndpoint = localEndpoint, let targetIP = targetIP {
                let musicMode = try Method.set_music(turn: .off, ownIP: localEndpoint.0, targetIP: targetIP)
                let message = try musicMode.string()
                
                controller.lights["0x0000000007e71ffd"]?.communicate(message)
                controller.lights["0x0000000007e71ffd"]?.state.musicMode = false
            }
            
        }
        catch let error {
            print(error)
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


