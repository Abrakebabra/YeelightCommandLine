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




/*
 JSON COMMANDS
 {"id":1,"method":"set_default","params":[]}
 {"id":1,"method":"set_scene", "params": ["hsv", 300, 70, 100]}
 
 {"id":1,"method":"get_prop","params":["power", "not_exist", "bright"]}
 */







/*
 JSON RESPONSES
 
 Standard Responses     [String]
 {"id":1, "result":["ok"]}
 
 get_pro Response       [String]
 {"id":1, "result":["on", "", "100"]}
 
 cron_get Response      [[String:Int]]
 {"id":1, "result":[{"type": 0, "delay": 15, "mix": 0}]}
 Will not accommodate this response within jsonDecoder.  If I use it, I'll make a separate function.  The function will need to return an any type to be dealt with after the jsonDecoder function has been called.
 
 Error Response
 {"id":2, "error":{"code":-1, “message”:"unsupported method"}}
 [String:[String:Any]]
 */

func jsonDecoder(Response data: Data) throws -> [String] {
    // Deserialize the data to a JSON object
    // Inspect contents of JSON object and look for "result" (ignore "id")
    // If no "result" found, look for "error"
    // Find error code and error message and throw error details
    // If error code and message not found, throw error on error object
    // If no "error" found, throw unknown error
    let deserializer = try JSONSerialization.jsonObject(with: data, options: [])
    
    guard let jsonObject = deserializer as? [String:Any] else {
        throw JSONError.jsonObject
    }
    
    guard let resultList = jsonObject["result"] as? [String] else {
        if let error = jsonObject["error"] as? [String:Any] {
            
            guard
                let errorCode: String = error["code"] as? String,
                let errorMessage: String = error["message"] as? String
                else {
                    throw JSONError.errorObject
            }
            
            throw JSONError.responseError("Error Code \(errorCode): \(errorMessage)")
            
        } else {
            throw JSONError.unknownError
        }
    }
    return resultList
}
