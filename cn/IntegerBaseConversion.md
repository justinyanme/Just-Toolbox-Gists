# Integer Base Conversion in Swift

使用Swift在不同进制的整数之间进行转换。系统的整数类型默认使用十进制，我们需要转换成String用于表达各种不同的进制。

十进制的基数/底数(Radix, base)是10，二进制是2，以此类推。

Swift在`Int`和`String`提供了进制转换方法，支持的范围是`2-36`，因为在`String`中如果要表达一个大于十进制的数，则除了`0-9`还需要用上`a-z`和`A-Z`，最多十个数字加上26个字母，一共36个字符。

以下为转换代码:

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

## 内部实现

那么Swift提供的`Int`和`String`类型的底数转换函数效率如何呢？Swift的Integers实现代码在这里: [https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Integers.swift (line 1497)](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Integers.swift#L1497)

可以看到这个方法是针对`BinaryInteger` protocol的，根据输入法radix把当前整数转为String。他先判断自己的位宽是否大于64位，如果小于等于64位，则用llvm的标准方法来转换。

我们一般用到Int64就完全足够了，所以先看标准实现。

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

分为有符号和无符号整形数，我们以`_int64ToString`为例，他的实现在: [https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Runtime.swift#L477](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/core/Runtime.swift#L477)

留意到真正的实现函数`_int64ToStringImpl`分为是否`$Embedded`两种实现。Swift后来支持嵌入式开发，可以参考官方Blog: [https://www.swift.org/blog/embedded-swift-examples/](https://www.swift.org/blog/embedded-swift-examples/)。这里我们就不看`Embedded`的实现了。

非Embedded这里只留下了一个函数声明:

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

其中`@_silgen_name`这个attribute是自[2015年这个commit](https://github.com/swiftlang/swift/commit/fbd2e4d872d1aa57bfba2ab1f4d280bb1e90cbb8)开始从`asmname`改名过来的。有阅读过操作系统源码的读者朋友应该对这种直接写汇编实现，业务层只保留一个函数声明的使用方法并不陌生。汇编写的符号一般习惯在前面加下划线`_`，所以这个Swift函数对应的符号是`_swift_int64ToString`，它的实现在这里: [https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/stubs/Stubs.cpp#L105](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/public/stubs/Stubs.cpp#L105)

这是一个C++函数，它的就是做了一下正负数判断然后调用`uint64ToStringImpl`:

```cpp
static uint64_t uint64ToStringImpl(char *Buffer, uint64_t Value,
                                   int64_t Radix, bool Uppercase,
                                   bool Negative) {
  char *P = Buffer; // 这里初始化 *P 指针指向缓冲区开始
  uint64_t Y = Value; // 这个就是要转换的那个整型数

  if (Y == 0) {
    *P++ = '0'; // 如果要转换的数是0，那就不用计算了直接填0
  } else if (Radix == 10) {
    // 如果底数/基数/进制是10，那就循环输入值从低位到高位，每个数字直接转成ASCII写入*P
    while (Y) {
      *P++ = '0' + char(Y % 10); // 这里的 '0' 对应ASCII编码起始，偏移 Y % 10 余数就是对应数字的ASCII值
      Y /= 10; // 这里偏移十进制一位，因为uint64_t就是默认十进制的
    }
  } else {
    // 如果底数/基数/进制不是10，那就调用llvm的方法来实现
    unsigned Radix32 = Radix;
    while (Y) {
      *P++ = llvm::hexdigit(Y % Radix32, !Uppercase);
      Y /= Radix32;
    }
  }

  // 这里补一下负数的符号
  if (Negative)
    *P++ = '-';

  // 缓冲区里的字符要反转一下，因为之前写入的时候是从低位到高位写入的
  // 比如十进制的 123，写入后变成 321，需要反转回来
  std::reverse(Buffer, P);

  // 最后返回的是缓冲区中字符串的长度
  // 我看Swift的注释中说32 bit Int肯定能装下这个长度，但返回值定义了uint64_t
  // 而且这是个ABI接口，不能随便改（有点无奈的意思）XD
  return size_t(P - Buffer);
}
```

那么`llvm:hedigit()`做了什么呢？它的实现在这里: [https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/include/llvm/ADT/StringExtras.h#L36](https://github.com/swiftlang/swift/blob/a861fc117b34fbabe67bc030823fb30b14d87d98/stdlib/include/llvm/ADT/StringExtras.h#L36)

```cpp
inline char hexdigit(unsigned X, bool LowerCase = false) {
  const char HexChar = LowerCase ? 'a' : 'A';
  // 这里和 *P++ = '0' + char(Y % 10); 的实现很像
  // 只是会判断＞0的情况下从'a'或者'A'起始作偏移
  return X < 10 ? '0' + X : HexChar + X - 10;
}
```

## 大数实现

那么以上就是Swift标准库里对64位整型数做基数转换的实现。但是Swift是支持大于64位的整数的，那么大数他怎么做的呢？

```swift
if self == (0 as Self) { return "0" }

// 如果底数/基数/进制是2^n，那么位移操作比除法要更高效
let isRadixPowerOfTwo = radix.nonzeroBitCount == 1
let radix_ = Magnitude(radix) // 这个函数只是把它转成对等的绝对值值
// 这里计算商和余数
func quotientAndRemainder( value: Magnitude) -> (Magnitude, Magnitude) {
    return isRadixPowerOfTwo
    ? (value >> radix.trailingZeroBitCount, value & (radix - 1))
    : value.quotientAndRemainder(dividingBy: radix)
}

// 这里把对应每一位数转成ASCII字符
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



// 这里就是循环一下每一位然后计算存进[UInt8]里面
// 这里有一段注释，提醒Swift标准库成员未来可以优化一下
// TODO(FIXME JIRA): All current stdlib types fit in small. Use a stack
// buffer instead of an array on the heap.
// 因为[UInt8]数组是分配在堆上的，如果用栈缓冲区来实现会更快。其实也就是上面CPP char* P版本的实现。
var result: [UInt8] = []
while value != 0 {
    let (quotient, remainder) = _quotientAndRemainder(value)
    result.append(_ascii(UInt8(truncatingIfNeeded: remainder)))
    value = quotient
}

if isNegative {
    result.append(UInt8(("-" as Unicode.Scalar).value))
}

// 同理，reverse一下最后return出去
result.reverse()
return result.withUnsafeBufferPointer {
    return String._fromASCII($0)
}
```