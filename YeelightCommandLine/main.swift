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

sleep(2)

for (key, value) in light.light {
    print("\(key): ip:\(value.ip)")
}

if light.light["0x00000000080394cb"] != nil {
    print("has light")
} else {
    print("light not found")
}

sleep(1)

while runProgram == true {
    let input: String? = readLine()
    
    switch input {
    case "on":
        let message = """
{"id":1, "method":"set_power", "params":["off", "smooth", 500]}\r\n
""".data(using: .utf8)
        
        
        light.light["0x00000000080394cb"]?.conn.testSend(message: message!)
        
    case "all off":
        print("Off")
        // turn off all statements
    case "exit":
        for (key, _) in light.light {
            light.light[key]?.conn.tcpConn.cancel()
        }
        sleep(2)
        runProgram = false
        
    default:
        continue
    }
    
}
print("LOOP ENDED")
