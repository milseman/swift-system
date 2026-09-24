/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import ArgumentParser
import SystemPackage

struct Access: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Check whether this process can read, write, or execute files, as test(1) does"
  )

  @Argument(help: "The files to check")
  var paths: [String]

  func run() throws {
    // An answer can be out of date as soon as it's given. To act on a
    // file, attempt the operation itself and handle its error instead.
    let kinds: [(name: String, access: FilePath.Access)] = [
      ("read", .read), ("write", .write), ("execute", .execute),
    ]
    for path in paths.map({ FilePath($0) }) {
      do {
        // The empty set checks only that the file exists.
        try path.checkAccess([])
      } catch {
        print("\(path): \(error)")
        continue
      }
      let answers = kinds.map { kind in
        do {
          try path.checkAccess(kind.access)
          return "\(kind.name) yes"
        } catch {
          return "\(kind.name) no (\(error))"
        }
      }
      print("\(path): \(answers.joined(separator: ", "))")
    }
  }
}
