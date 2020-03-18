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
    case stateInitFailed(String)
    case stringUnwrapFailed
}

enum CommandError: Error {
    case invalidString
}
