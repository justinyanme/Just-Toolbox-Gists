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