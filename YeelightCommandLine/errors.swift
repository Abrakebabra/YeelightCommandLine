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
    case propertyKey
    case idValue
}


enum RequestError: Error {
    case stringToData
    case methodNotValid // not yet used
}


enum JSONError: Error {
    case jsonObject
    case errorObject
    case response(String)
    case noData
    case unknown(Any?)
}


// change this or make a new one to reflect the new state updater?
enum LightStateUpdateError: Error {
    case value(String)
}
