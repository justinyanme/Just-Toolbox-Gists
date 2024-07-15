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