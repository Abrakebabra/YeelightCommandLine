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

