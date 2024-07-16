# Integer Base Conversion in Swift

Use Swift to convert integers between different bases. The system’s integer type defaults to decimal, and we need to convert it to a String to express various different bases.

The base (radix) of decimal is 10, binary is 2, and so on.

Swift provides methods for base conversion in Int and String, supporting a range of 2-36, because to represent a number greater than decimal in String, besides 0-9, we need to use a-z and A-Z. There are a maximum of ten digits plus 26 letters, making a total of 36 characters.

Here is the conversion code:

```swift
enum IntegerBase: Int, CaseIterable {
    case binary = 2
    case octal = 8
    case decimal = 10
    case hexadecimal = 16

    var title: String {
        switch self {
        case .binary: "Binary (2)".localized
        case .octal: "Octal (8)".localized
        case .decimal: "Decimal (10)".localized
        case .hexadecimal: "Hexadecimal (16)".localized
        }
    }
}

func convert(text: String, from: IntegerBase, to: IntegerBase) -> String? {
    var decimal: Int = -1
    // Radix must be between 2 and 36
    //
    // To string
    // String(aInt, radix: 2)
    //
    // From string
    // Int(b2, radix: 2)
    //
    guard let aDecimal = Int(text, radix: from.rawValue) else {
        log.error("Invalid \(from) based number: \(text)")
        return nil
    }

    decimal = aDecimal

    if decimal == -1 {
        log.error("Invalid decimal -1!")
        return nil
    }

    if from != to {
        return String(decimal, radix: to.rawValue)

    } else {
        return String(decimal)
    }
}
```

## Internal Implementation

How efficient are the radix conversion functions provided by Swift for the Int and String types? The implementation of Swift's Integers can be found here: [https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Integers.swift (line 1497).](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Integers.swift#L1497)

This method targets the `BinaryInteger` protocol and converts the current integer to a `String` based on the input radix. It first checks if the bit width is greater than 64 bits. If it is 64 bits or less, it uses the standard LLVM method for conversion.

For most use cases, `Int64` is sufficient, so let's first look at the standard implementation.

```swift
if bitWidth <= 64 {
    let radix_ = Int64(radix)
    return Self.isSigned
    ? _int64ToString(
        Int64(truncatingIfNeeded: self), radix: radix_, uppercase: uppercase)
    : _uint64ToString(
        UInt64(truncatingIfNeeded: self), radix: radix_, uppercase: uppercase)
}
```

This is divided into signed and unsigned integers. Taking _int64ToString as an example, its implementation can be found here: [https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Runtime.swift#L477](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Runtime.swift#L477).

Notice that the actual implementation function _int64ToStringImpl is divided into implementations for $Embedded or not. Swift later added support for embedded development, which can be referenced in the official blog: [https://www.swift.org/blog/embedded-swift-examples/](https://www.swift.org/blog/embedded-swift-examples/). Here, we will not look at the embedded implementation.

For non-embedded, only a function declaration remains:

```swift
@_silgen_name("swift_int64ToString")
internal func _int64ToStringImpl(
  _ buffer: UnsafeMutablePointer<UTF8.CodeUnit>,
  _ bufferLength: UInt,
  _ value: Int64,
  _ radix: Int64,
  _ uppercase: Bool
) -> UInt64
```

The attribute `@_silgen_name` was renamed from asmname starting from [this commit in 2015](https://github.com/swiftlang/swift/commit/fbd2e4d872d1aa57bfba2ab1f4d280bb1e90cbb8). Readers familiar with operating system source code may recognize this method of directly writing assembly implementations while keeping only a function declaration in the business layer. Symbols written in assembly often start with an underscore _, so the corresponding Swift function symbol is `_swift_int64ToString`, and its implementation is here: https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/stubs/Stubs.cpp#L105.

This is a C++ function that performs a check for negative numbers and then calls `uint64ToStringImpl`:

```cpp
static uint64_t uint64ToStringImpl(char *Buffer, uint64_t Value,
                                   int64_t Radix, bool Uppercase,
                                   bool Negative) {
  char *P = Buffer; // Initialize *P pointer to the start of the buffer
  uint64_t Y = Value; // This is the integer to be converted

  if (Y == 0) {
    *P++ = '0'; // If the value to convert is 0, write 0 directly
  } else if (Radix == 10) {
    // If the radix is 10, loop through the input value from least significant to most significant digit, converting each digit to ASCII and writing it to *P
    while (Y) {
      *P++ = '0' + char(Y % 10); // '0' corresponds to the starting ASCII code, offset by the remainder of Y % 10 which gives the corresponding digit's ASCII value
      Y /= 10; // Shift the decimal place
    }
  } else {
    // If the radix is not 10, call the LLVM method to handle the conversion
    unsigned Radix32 = Radix;
    while (Y) {
      *P++ = llvm::hexdigit(Y % Radix32, !Uppercase);
      Y /= Radix32;
    }
  }

  // Add the negative sign if necessary
  if (Negative)
    *P++ = '-';

  // Reverse the buffer as characters were written from least significant to most significant digit
  // For example, decimal 123 written as 321 needs to be reversed
  std::reverse(Buffer, P);

  // Return the length of the string in the buffer
  // Swift's comment mentions that 32-bit Int can definitely fit this length, but the return value is defined as uint64_t
  // This is an ABI interface, so it can't be changed lightly (a bit reluctantly) XD
  return size_t(P - Buffer);
}
```

What does `llvm:hexdigit()` do? Its implementation can be found here: [https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/include/llvm/ADT/StringExtras.h#L36](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/include/llvm/ADT/StringExtras.h#L36).

```cpp
inline char hexdigit(unsigned X, bool LowerCase = false) {
  const char HexChar = LowerCase ? 'a' : 'A';
  // Similar to *P++ = '0' + char(Y % 10);
  // But it offsets from 'a' or 'A' for values > 0
  return X < 10 ? '0' + X : HexChar + X - 10;
}
```

## Implementation for Big Int

The above describes the radix conversion implementation for 64-bit integers in the Swift standard library. However, Swift supports integers larger than 64 bits, so how does it handle those?

```swift
if self == (0 as Self) { return "0" }

// If the radix is a power of 2, bit shifting is more efficient than division
let isRadixPowerOfTwo = radix.nonzeroBitCount == 1
let radix_ = Magnitude(radix) // Converts to the corresponding absolute value
// Compute quotient and remainder
func quotientAndRemainder( value: Magnitude) -> (Magnitude, Magnitude) {
    return isRadixPowerOfTwo
    ? (value >> radix.trailingZeroBitCount, value & (radix - 1))
    : value.quotientAndRemainder(dividingBy: radix)
}

// Convert each digit to ASCII character
let hasLetters = radix > 10
func ascii( digit: UInt8) -> UInt8 {
    let base: UInt8
    if !hasLetters || digit < 10 {
    base = UInt8(("0" as Unicode.Scalar).value)
    } else if uppercase {
    base = UInt8(("A" as Unicode.Scalar).value) &- 10
    } else {
    base = UInt8(("a" as Unicode.Scalar).value) &- 10
    }
    return base &+ digit
}

let isNegative = Self.isSigned && self < (0 as Self)
var value = magnitude

// Loop through each digit and store in [UInt8] array
// There is a comment here reminding Swift standard library members to optimize this in the future
// TODO (FIXME JIRA): All current stdlib types fit in small. Use a stack
// buffer instead of an array on the heap.
// Since the [UInt8] array is allocated on the heap, using a stack buffer would be faster. Essentially, this is similar to the char* P version in C++.
var result: [UInt8] = []
while value != 0 {
    let (quotient, remainder) = _quotientAndRemainder(value)
    result.append(_ascii(UInt8(truncatingIfNeeded: remainder)))
    value = quotient
}

if isNegative {
    result.append(UInt8(("-" as Unicode.Scalar).value))
}

// Reverse and return the result
result.reverse()
return result.withUnsafeBufferPointer {
    return String._fromASCII($0)
}
```