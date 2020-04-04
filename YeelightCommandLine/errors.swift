//
//  errors.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/11.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation


enum DiscoveryError: Error {
    case tcpInitFailed(String)
    case propertyStringUnwrapFailed
}

enum CommandError: Error {
    case invalidString
    case noResponse
}

enum JSONError: Error {
    case responseError(String)
    case errorObject
    case jsonObject
    case noData
    case unknownError
}

enum LightStateError: Error {
    case param1(String)
    case param2(String)
    case param3(String)
    case param4(String)
}
