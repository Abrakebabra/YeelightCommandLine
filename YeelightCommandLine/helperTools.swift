//
//  helperTools.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/15.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

// convert String to Int
func stringToInt(String string: String) throws -> Int {
    guard let integer = Int(string) else {
        throw convertError.stringIntFailed
    }
    
    return integer
}


// convert String to Bool
