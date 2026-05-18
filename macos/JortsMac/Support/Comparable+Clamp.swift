import CoreGraphics
import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension NSRange {
    func clamped(toLength length: Int) -> NSRange {
        let location = Swift.min(Swift.max(0, self.location), length)
        let maxLength = Swift.max(0, length - location)
        return NSRange(location: location, length: Swift.min(self.length, maxLength))
    }
}
