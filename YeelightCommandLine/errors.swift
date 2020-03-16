//
//  errors.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/11.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

// currently not used
enum DiscoveryError: Error {
    case initFailed(String)
    case dataParse
    case noLightsFound
}
