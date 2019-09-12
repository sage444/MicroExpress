// swift-tools-version:5.0
//
//  Package.swift
//  MicroExpress
//
//  Created by Helge Hess on 09.03.18.
//  Copyright © 2018-2019 ZeeZide. All rights reserved.
//
import PackageDescription

let package = Package(
    name: "MicroExpress",
    
    products: [
        .library(name: "MicroExpress", targets: ["MicroExpress"]),
    ],
    
    dependencies: [
        /* Add your package dependencies in here
        .package(url: "https://github.com/AlwaysRightInstitute/cows.git",
                 from: "1.0.0"),
        */
        .package(url: "https://github.com/apple/swift-nio.git", 
                 .upToNextMajor(from: "2.0.0")),
        /*
        .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
                 from: "0.5.7")
 */
    ],

    targets: [
        .target(name: "MicroExpress", 
                dependencies: [
                    /* Add your target dependencies in here, e.g.: */
                    // "cows",
                    "NIO",
                    "NIOHTTP1" /*,
                    "mustache"
 */
 
                ])
    ]
)
