//
//  main.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/09.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

let connQueue = DispatchQueue(label: "Connection Queue")
let procQueue = DispatchQueue(label: "Process Queue")
let semaphore = DispatchSemaphore(value: 1)

var lightsRemaining = 6

let light = Yeelight()
light.discover()

/*
let lightCount: Int = 0
var readyCount: Int = 0
while lightCount > readyCount {
    readyCount = 0
    
    for (key, _) in light.light {
        
        if light.light[key]?.conn.status == "ready" {
            readyCount += 1
        }
    }
}
*/


sleep(2)

for (key, value) in light.light {
    print("\(key): ip:\(value.ip)")
}


while true {
    let input: String? = readLine()
    
    if input == "exit" {
        for (key, _) in light.light {
            light.light[key]?.conn.conn.cancel()
        }
        sleep(1)
        break
    }
}
