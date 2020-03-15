//
//  errors.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/11.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation


enum dataParseError: Error {
    case initFailed
    // etc...
}


enum convertError: Error {
    case stringIntFailed
    case stringBoolFailed
}
