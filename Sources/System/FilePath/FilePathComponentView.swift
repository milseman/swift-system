/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - API

@available(System 0.0.2, *)
extension FilePath {
  /// A bidirectional, range replaceable collection of the non-root components
  /// that make up a file path.
  ///
  /// ComponentView provides access to standard `BidirectionalCollection`
  /// algorithms for accessing components from the front or back, as well as
  /// standard `RangeReplaceableCollection` algorithms for modifying the
  /// file path using component or range of components granularity.
  ///
  /// Example:
  ///
  ///     var path: FilePath = "/./home/./username/scripts/./tree"
  ///     let scriptIdx = path.components.lastIndex(of: "scripts")!
  ///     path.components.insert("bin", at: scriptIdx)
  ///     // path is "/./home/./username/bin/scripts/./tree"
  ///
  ///     path.components.removeAll { $0.kind == .currentDirectory }
  ///     // path is "/home/username/bin/scripts/tree"
  @available(System 0.0.2, *)
  public struct ComponentView: Sendable {
    internal var _path: FilePath
    internal var _start: SystemString.Index

    internal init(_ path: FilePath) {
      self._path = path
      self._start = path._relativeStart
      _invariantCheck()
    }
  }

  /// View the non-root components that make up this path.
  ///
  /// This property provides read and write access to the path's non-root
  /// components as a collection. When read, it returns a view of the
  /// components. When modified, changes are applied back to the path while
  /// preserving the root.
  public var components: ComponentView {
    __consuming get { ComponentView(self) }
    _modify {
      // RRC's empty init means that we can't guarantee that the yielded
      // view will restore our root. So copy it out first.
      //
      // TODO(perf): Small-form root (especially on Unix). Have Root
      // always copy out (not worth ref counting). Make sure that we're
      // not needlessly sliding values around or triggering a COW
      let rootStr = self.root?._systemString ?? SystemString()
      var comp = ComponentView(self)
      self = FilePath()
      defer {
        self = comp._path
        if root?._slice.elementsEqual(rootStr) != true {
          self.root = Root(rootStr)
        }
      }
      yield &comp
    }
  }
}

@available(System 0.0.2, *)
extension FilePath.ComponentView: BidirectionalCollection {
  public typealias Element = FilePath.Component

  /// A position in a `ComponentView`.
  ///
  /// This type represents an index into the component view, allowing
  /// bidirectional traversal of path components.
  @available(System 0.0.2, *)
  public struct Index: Sendable, Comparable, Hashable {
    internal typealias Storage = SystemString.Index

    internal var _storage: Storage

    /// Returns a Boolean value indicating whether the first index is less than
    /// the second.
    ///
    /// - Parameters:
    ///   - lhs: The first index to compare.
    ///   - rhs: The second index to compare.
    /// - Returns: `true` if `lhs` is less than `rhs`; otherwise, `false`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs._storage < rhs._storage
    }

    fileprivate init(_ idx: Storage) {
      self._storage = idx
    }
  }

  /// The position of the first component in the view.
  ///
  /// If the view is empty, `startIndex` is equal to `endIndex`.
  public var startIndex: Index { Index(_start) }

  /// The position one past the last component in the view.
  ///
  /// `endIndex` is not a valid argument to `subscript`. It is always reachable
  /// from `startIndex` by zero or more applications of `index(after:)`.
  public var endIndex: Index { Index(_path._storage.endIndex) }

  /// Returns the position immediately after the given index.
  ///
  /// - Parameter i: A valid index of the collection. `i` must be less than
  ///   `endIndex`.
  /// - Returns: The index value immediately after `i`.
  public func index(after i: Index) -> Index {
    return Index(_path._parseComponent(startingAt: i._storage).nextStart)
  }

  /// Returns the position immediately before the given index.
  ///
  /// - Parameter i: A valid index of the collection. `i` must be greater than
  ///   `startIndex`.
  /// - Returns: The index value immediately before `i`.
  public func index(before i: Index) -> Index {
    Index(_path._parseComponent(priorTo: i._storage).lowerBound)
  }

  /// Accesses the component at the specified position.
  ///
  /// - Parameter position: The position of the component to access. `position`
  ///   must be a valid index of the collection that is not equal to `endIndex`.
  /// - Returns: The component at the specified position.
  public subscript(position: Index) -> FilePath.Component {
    let end = _path._parseComponent(startingAt: position._storage).componentEnd
    return FilePath.Component(_path, position._storage ..< end)
  }
}

@available(System 0.0.2, *)
extension FilePath.ComponentView: RangeReplaceableCollection {
  /// Creates an empty component view.
  ///
  /// This initializer creates a view with no components, representing an
  /// empty relative path with no root.
  public init() {
    self.init(FilePath())
  }

  // TODO(perf): We probably want to have concrete overrides or generic
  // specializations taking FP.ComponentView and
  // FP.ComponentView.SubSequence because we
  // can just memcpy in those cases. We
  // probably want to do that for all RRC operations.

  /// Replaces a range of components with the elements of a collection.
  ///
  /// This method replaces the components in the specified range with the
  /// components from `newElements`. The number of new components need not
  /// match the number of components being replaced.
  ///
  /// - Parameters:
  ///   - subrange: The range of components to replace. The bounds of the range
  ///     must be valid indices of the collection.
  ///   - newElements: The new components to add to the component view.
  public mutating func replaceSubrange<C>(
    _ subrange: Range<Index>, with newElements: C
  ) where C : Collection, Self.Element == C.Element {
    defer {
      _path._invariantCheck()
      _invariantCheck()
    }
    if isEmpty {
      _path = FilePath(root: _path.root, newElements)
      return
    }
    let range = subrange.lowerBound._storage ..< subrange.upperBound._storage
    if newElements.isEmpty {
      let fromEnd = subrange.upperBound == endIndex
      _path._storage.removeSubrange(range)
      if fromEnd {
        _path._removeTrailingSeparator()
      }
      return
    }

    // TODO(perf): Avoid extra allocation by sliding elements down and
    // filling in the bytes ourselves.

    // If we're inserting at the end, we need a leading separator.
    var str = SystemString()
    let atEnd = subrange.lowerBound == endIndex
    if atEnd {
      str.append(platformSeparator)
    }
    str.appendComponents(components: newElements)
    if !atEnd {
      str.append(platformSeparator)
    }
    _path._storage.replaceSubrange(range, with: str)
  }
}

@available(System 0.0.2, *)
extension FilePath {
  /// Creates a file path from a root and a collection of components.
  ///
  /// This initializer constructs a complete file path by combining an optional
  /// root with a collection of path components. If no root is provided, the
  /// resulting path will be relative.
  ///
  /// - Parameters:
  ///   - root: An optional root for the path. Pass `nil` for a relative path.
  ///   - components: A collection of components to append after the root.
  public init<C: Collection>(
    root: Root?, _ components: C
  ) where C.Element == Component {
    var str = root?._systemString ?? SystemString()
    str.appendComponents(components: components)
    self.init(str)
  }

  /// Creates a file path from a root and any number of components.
  ///
  /// This convenience initializer allows you to specify path components using
  /// a variadic parameter list.
  ///
  /// - Parameters:
  ///   - root: An optional root for the path. Pass `nil` for a relative path.
  ///   - components: Zero or more components to append after the root.
  public init(root: Root?, components: Component...) {
    self.init(root: root, components)
  }

  /// Creates a file path from an optional root and a slice of another path's
  /// components.
  ///
  /// This initializer efficiently constructs a path from a root and a
  /// subsequence of components extracted from another path's component view.
  ///
  /// - Parameters:
  ///   - root: An optional root for the path. Pass `nil` for a relative path.
  ///   - components: A subsequence of components from another path's
  ///     component view.
  public init(root: Root?, _ components: ComponentView.SubSequence) {
    var str = root?._systemString ?? SystemString()
    let (start, end) =
      (components.startIndex._storage, components.endIndex._storage)
    str.append(contentsOf: components.base._slice[start..<end])
    self.init(str)
  }
}

// MARK: - Internals

@available(System 0.0.2, *)
extension FilePath.ComponentView: _PathSlice {
  internal var _range: Range<SystemString.Index> {
    _start ..< _path._storage.endIndex
  }

  internal init(_ str: SystemString) {
    fatalError("TODO: consider dropping proto req")
  }
}

// MARK: - Invariants

@available(System 0.0.2, *)
extension FilePath.ComponentView {
  internal func _invariantCheck() {
    #if DEBUG
    if isEmpty {
      precondition(_path.isEmpty == (_path.root == nil))
      return
    }

    // If path has a root,
    if _path.root != nil {
      precondition(first!._slice.startIndex > _path._storage.startIndex)
      precondition(first!._slice.startIndex == _path._relativeStart)
    }

    self.forEach { $0._invariantCheck() }

    if let base = last {
      precondition(base._slice.endIndex == _path._storage.endIndex)
    }

    precondition(FilePath(root: _path.root, self) == _path)
    #endif // DEBUG
  }
}
