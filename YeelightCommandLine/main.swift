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
            let message = try Method.set_power(.on, .sudden).string
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "off":
        do {
            let message = try Method.set_power(.off, .sudden).string
            controller.lights["0x0000000007e71ffd"]?.communicate(message)
        }
        catch let error {
            print(error)
        }
        
    case "allOn":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power.init(.on, .sudden).string
                value.communicate(message)
            }
            catch let error {
                print(error)
            }
        }
        
    case "allOff":
        for (_, value) in controller.lights {
            do {
                let message = try Method.set_power.init(.off, .sudden).string
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
