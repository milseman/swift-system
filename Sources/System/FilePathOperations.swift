/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/



// @available(whatever)
extension FilePath {

  // Whether the path has a root
  //
  // Unix: Path starts with '/'
  // Windows: After prefix comes either '/' or '\\'
  public var hasRoot: Bool {
    guard let first = hasPrefix ? components.dropFirst().first : components.first else {
      return false
    }
    return first.isRoot
  }

  public var hasPrefix: Bool { false }

  // FIXME: Include `~` as an absolute path first component. Rust doesn't for some reason...
  public var isAbsolute: Bool {
    return components.first?.isRoot ?? false
  }

  public var isRelative: Bool { !isAbsolute }

  public mutating func append(_ other: FilePath) {
    // TODO: We can do a faster byte copy operation, after checking
    // for leading/trailing slashes...
    self.components.append(contentsOf: other.components)
  }

  public static func +(_ lhs: FilePath, _ rhs: FilePath) -> FilePath {
    var result = lhs
    result.append(rhs)
    return result
  }

  /* TODO:
  public mutating func push(_ component: FilePath.Component) {
  }
  public mutating func push(_ path: FilePath) {
  }
  public mutating func push<C: Collection>(
    contentsOf components: C
  ) where C.Element == FilePath.Component {
  }

  @discardableResult
  public mutating func pop() -> FilePath.Component? {
    ... or should this trap if empty?
  }
  @discardableResult
  public mutating func pop(_ n: Int) -> FilePath.Component? {
   ... or should this trap if empty?
  }
 */
}
