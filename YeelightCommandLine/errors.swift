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

enum RequestError: Error {
    case stringToData
    case methodNotValid
}

enum JSONError: Error {
    case jsonObject
    case idError
    case errorObject
    case responseError(String)
    case noData
    case unknownError
}

enum LightStateUpdateError: Error {
    case methodNotInSwitch(String)
    case param1(String)
    case param2(String)
    case param3(String)
    case param4(String)
}
