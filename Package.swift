// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "swift-canvas-renderer",
                      platforms: [
                          .macOS(.v14)
                      ],
                      products: [
                        .library(name: "CanvasRender", type: nil, targets: ["CanvasRender"]),
                        .executable(name: "CanvasRenderExecutable", targets: ["swift-canvas-renderer"])
                      ],
                      dependencies: [
                      ],
                      targets: [
                          .executableTarget(name: "swift-canvas-renderer",
                                            dependencies: [.target(name: "CanvasRender")]),
                          .target(name: "CanvasRender",
                                  dependencies: []),

                      ])
