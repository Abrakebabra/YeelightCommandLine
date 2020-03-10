//
//  main.swift
//  YeelightCommandLine
//
//  Created by Keith Lee on 2020/03/09.
//  Copyright © 2020 Keith Lee. All rights reserved.
//

import Foundation

let connQueue = DispatchQueue(label: "Connection Queue")
let procQueue = DispatchQueue(label: "Process Queue")
let semaphore = DispatchSemaphore(value: 1)

