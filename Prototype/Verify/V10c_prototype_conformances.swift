// V10c: can OwnedFD take FileDescriptor's conformances (Hashable, Codable, RawRepresentable)?
import SystemPackage
extension OwnedFD: @retroactive Equatable {
  public static func == (lhs: borrowing OwnedFD, rhs: borrowing OwnedFD) -> Bool { true }
}
