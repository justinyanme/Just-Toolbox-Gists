# Generate Random Token with Swift

Implementing a random token generator is quite simple. You concatenate uppercase characters, lowercase characters, numeric characters, and symbol characters, then shuffle the individual characters. Here is the code:

```swift
@State private var uppercaseEnabled = true
@State private var numbersEnabled = true
@State private var lowercaseEnabled = true
@State private var symbolsEnabled = false
@State private var length = 64

func createToken() -> String {
    let uppercase = uppercaseEnabled ? "ABCDEFGHIJKLMOPQRSTUVWXYZ" : ""
    let lowercase = lowercaseEnabled ? "abcdefghijklmopqrstuvwxyz" : ""
    let numbers = numbersEnabled ? "0123456789" : ""
    let symbols = symbolsEnabled ? ".,;:!?./-"'#{([-|\@)]=}*+" : ""

    let originStr = (uppercase + lowercase + numbers + symbols)
    let shuffledStr = String(repeating: originStr, count: length / originStr.count + 1).shuffled
    let endIndex = shuffledStr.index(shuffledStr.startIndex, offsetBy: length)
    return String(shuffledStr[..<endIndex])
}
```

The `shuffled` method of `Collection` is implemented as follows:

```swift
extension RangeReplaceableCollection {
    var shuffled: Self {
        var elements = self
        return elements.shuffleInPlace()
    }

    @discardableResult
    mutating func shuffleInPlace() -> Self {
        indices.forEach {
            let subSequence = self[$0...$0]
            let index = indices.randomElement()!
            replaceSubrange($0...$0, with: self[index...index])
            replaceSubrange(index...index, with: subSequence)
        }
        return self
    }
    func choose(_ n: Int) -> SubSequence { return shuffled.prefix(n) }
}
```

## Internal Implementation

So how is Swift's `randomElement()` implemented? You can find its source code at: [https://github.com/swiftlang/swift/blob/ac0f574fdb9d9bbaa6a60a4815c5e20c051604ac/stdlib/public/core/Collection.swift#L954](https://github.com/swiftlang/swift/blob/ac0f574fdb9d9bbaa6a60a4815c5e20c051604ac/stdlib/public/core/Collection.swift#L954)

```swift
/// Returns a random element of the collection.
///
/// Call `randomElement()` to select a random element from an array or
/// another collection. This example picks a name at random from an array:
///
///     let names = ["Zoey", "Chloe", "Amani", "Amaia"]
///     let randomName = names.randomElement()!
///     // randomName == "Amani"
///
/// This method is equivalent to calling `randomElement(using:)`, passing in
/// the system's default random generator.
///
/// - Returns: A random element from the collection. If the collection is
///   empty, the method returns `nil`.
///
/// - Complexity: O(1) if the collection conforms to
///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
///   of the collection.
@inlinable
public func randomElement() -> Element? {
var g = SystemRandomNumberGenerator()
return randomElement(using: &g)
}
```

In different platforms, `SystemRandomNumberGenerator()` has different implementations. In the Swift standard library, it just links to a symbol. According to the [official documentation](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator):

- Apple platforms use `arc4random_buf(3)`.
- Linux platforms use `getrandom(2)` when available; otherwise, they read from `/dev/urandom`.
- Windows uses `BCryptGenRandom`.

Let's look at the implementation of `arc4random_buf` on Apple platforms. It is implemented in the `Libc` of the `FreeBSD` project. You can find the source code [here](https://opensource.apple.com/source/Libc/Libc-825.26/gen/FreeBSD/arc4random.c.auto.html):

```c
void
arc4random_buf(void *_buf, size_t n)
{
	u_char *buf = (u_char *)_buf;
	int did_stir = 0;

	THREAD_LOCK();

	while (n--) {
		if (arc4_check_stir())
		{
			did_stir = 1;
		}
		buf[n] = arc4_getbyte();
		arc4_count--;
	}
	
	THREAD_UNLOCK();
	if (did_stir)
	{
		/* stirring used up our data pool, we need to read in new data outside of the lock */
		arc4_fetch();
		rs_data_available = 1;
		__sync_synchronize();
	}
}
```

The most important function here is `arc4_fetch()`, which is the system's implementation for fetching the random source. Here is its code:

```c
static void
arc4_fetch(void)
{
	int done, fd;
    // Below, RANDOMDEV is defined as:
    // #define	RANDOMDEV	"/dev/random"
	fd = _open(RANDOMDEV, O_RDONLY, 0);
	done = 0;
	if (fd >= 0) {
		if (_read(fd, &rdat, KEYSIZE) == KEYSIZE)
			done = 1;
		(void)_close(fd);
	} 
	if (!done) {
		(void)gettimeofday(&rdat.tv, NULL);
		rdat.pid = getpid();
		/* We'll just take whatever was on the stack too... */
	}
}
```

The operating system obtains entropy sources from the `/dev/random` device, which is a typical implementation of Unix-like OS. Another device is `/dev/urandom`, and in Apple's operating systems, the implementations of these two are the same.

In earlier system implementations, entropy sources were collected from hardware and then encrypted using cryptographic algorithms (such as ChaCha20) and stored. Apple may have switched their algorithm to Fortuna as early as 2019 or earlier. The entropy sources used include ([original text](https://support.apple.com/en-ie/guide/security/seca0c73a75b/web)):

- [True random numbers generated by Secure Enclave hardware](https://support.apple.com/en-ie/guide/security/sec59b0b31ff/web)
- CPU execution time jitter during startup ([see this article for what CPU execution time jitter is](https://lwn.net/Articles/642166/))
- Hardware interrupt signals (such as keyboard and mouse events)
- Random seed file saved during startup
- Intel random instructions such as `RDSEED` and `RDRAND` (only available on Intel-based Macs)

It seems that the most impressive source here is the Secure Enclave Processor, a secure dedicated hardware introduced with the iPhone 5s. Generally, the places where we use random number results, such as the token above, are used for verification. If an attacker knows the random seed, then the pseudo-random results generated will be fixed, and they can infer the random results and bypass token verification. The true random entropy source at the hardware level adopted by Apple can effectively counter such attacks.
