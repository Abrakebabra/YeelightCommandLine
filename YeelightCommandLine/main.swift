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

let testQueue = DispatchQueue(label: "Test")

testQueue.async {
    controller.discover()
}


sleep(2)

for (key, value) in controller.lights {
    print("\(key): ip:\(value.info.ip)")
}


if controller.lights["0x0000000007e71ffd"] != nil {
    print("has light")
} else {
    print("light not found")
}


while runProgram == true {
    print("Awaiting input")
    let input: String? = readLine()
    
    switch input {
    case "on":
        do {
            try controller.lights["0x0000000007e71ffd"]?.communicate(method: Light.methodEnum.set_power, "on", "sudden", 0)
        }
        catch let error {
            print(error)
        }
        
    case "off":
        do {
            try controller.lights["0x0000000007e71ffd"]?.communicate(method: Light.methodEnum.set_power, "off", "sudden", 0)
        }
        catch let error {
            print(error)
        }
        
    case "allOn":
        for (_, value) in controller.lights {
            do {
                try value.communicate(method: Light.methodEnum.set_power, "on", "sudden", 0)
            }
            catch let error {
                print(error)
            }
        }
        
    case "allOff":
        for (_, value) in controller.lights {
            do {
                try value.communicate(method: Light.methodEnum.set_power, "off", "sudden", 0)
            }
            catch let error {
                print(error)
            }
        }
    case "exit":
        for (key, _) in controller.lights {
            controller.lights[key]?.tcp.conn.cancel()
        }
        sleep(2)
        runProgram = false
        
    default:
        continue
    }
    
}
print("PROGRAM END")
