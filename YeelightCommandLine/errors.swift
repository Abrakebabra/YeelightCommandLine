//
//  errors.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/11.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation


public enum DiscoveryError: Error {
    case tcpInitFailed(String)
    case propertyKey
    case idValue
}


public enum RequestError: Error {
    case stringToData
    case methodNotValid // not yet used
}


public enum JSONError: Error {
    case jsonObject
    case errorObject
    case response(String)
    case noData
    case unknown(Any?)
}


// change this or make a new one to reflect the new state updater?
public enum LightStateUpdateError: Error {
    case value(String)
}


public enum MethodError: Error {
    case durationBeyondRange
    case brightBeyondRange
    case ctBeyondRange
    case rgbBeyondRange
    case hueBeyondRange
}
