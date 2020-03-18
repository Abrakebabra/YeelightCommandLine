//
//  helperTools.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/15.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

// convert String to Int
func stringIntConvert(String string: String) -> Int? {
    if let integer = Int(string) {
        return integer
    } else {
        return nil
    }
}


struct Response {
    let id: Int
    let result: [String]
    // is result an array with dictionary inside, or array?
    // or get array then
}

/*
 EXAMPLE COMMANDS
 {"id":1,"method":"set_default","params":[]}
 {"id":1,"method":"set_scene", "params": ["hsv", 300, 70, 100]}
 
 {"id":1,"method":"get_prop","params":["power", "not_exist", "bright"]}

 
 EXAMPLE RESPONSES
 {"id":1, "result":["ok"]}
 {"id":1, "result":[{"type": 0, "delay": 15, "mix": 0}]}
 
 {"id":1, "result":["on", "", "100"]}
 
 
 [String]
 [[String:Int]]
 [String]
 
*/
 
// convert inputs to JSON

// read JSON to dictionary
