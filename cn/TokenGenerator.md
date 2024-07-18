# Generate Random Token with Swift

生成随机Token的实现很简单，把大写字符，小写字符，数字字符还有符号字符四种拼到一起，再随机一下单个字符即可，代码如下:

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
    let symbols = symbolsEnabled ? ".,;:!?./-\"'#{([-|\\@)]=}*+" : ""

    let originStr = (uppercase + lowercase + numbers + symbols)
    let shuffledStr = String(repeating: originStr, count: length / originStr.count + 1).shuffled
    let endIndex = shuffledStr.index(shuffledStr.startIndex, offsetBy: length)
    return String(shuffledStr[..<endIndex])
}
```

其中`Collection`的`shuffled`方法是这样的:

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

## 内部实现

那么Swift的`randomElement()`又是如何实现的呢？它的源码在: [https://github.com/swiftlang/swift/blob/ac0f574fdb9d9bbaa6a60a4815c5e20c051604ac/stdlib/public/core/Collection.swift#L954](https://github.com/swiftlang/swift/blob/ac0f574fdb9d9bbaa6a60a4815c5e20c051604ac/stdlib/public/core/Collection.swift#L954)

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

这里面`SystemRandomNumberGenerator()`在不同平台有不同的实现，Swift标准库里只是链接了一个符号，[官方文档](https://developer.apple.com/documentation/swift/systemrandomnumbergenerator)说:

- Apple platforms use `arc4random_buf(3)`.
- Linux platforms use `getrandom(2)` when available; otherwise, they read from `/dev/urandom`.
- Windows uses `BCryptGenRandom`.

我们看看Apple platforms的实现`arc4random_buf`，它的实现是`FreeBSD`项目中`Libc`里，源码[在这里](https://opensource.apple.com/source/Libc/Libc-825.26/gen/FreeBSD/arc4random.c.auto.html):

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

这里面最重要的其实是这个函数`arc4_fetch()`，这个函数是系统用来取随机源的实现，它的代码如下:

```c
static void
arc4_fetch(void)
{
	int done, fd;
    // 下面这个RANDOMDEV是
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

操作系统会从`/dev/random`这个设备获取熵源，这是典型的Unix-like OS的实现，另一个设备是`/dev/urandom`，在苹果的操作系统中，这两个的实现没有区别。

早期系统实现是从硬件收集各种熵源(entropy source)，然后使用加密算法(比如ChaCha20)加密存储。苹果可能从2019年或更早就它们的算法切到Fortuna，使用的熵源包括([原文地址](https://support.apple.com/en-ie/guide/security/seca0c73a75b/web)):

- [Secure Enclave硬件给出的真随机数](https://support.apple.com/en-ie/guide/security/sec59b0b31ff/web)
- 启动阶段的CPU执行时间差([参考这篇文章介绍什么是CPU execution time jitter](https://lwn.net/Articles/642166/))
- 硬件中断信号(比如键盘鼠标事件之类的)
- 启动时保存起来的随机种子文件
- Intel的随机指令 — 比如`RDSEED`和`RDRAND` (只有Intel-based Mac才能用)

看起来这里面最厉害的还是iPhone 5s时代推出的安全专属硬件Secure Enclave处理器。一般我们应用随机数结果的地方，像上面的Token就是用来做校验的。如果攻击者知道随机种子是什么，那么伪随机生成的结果就是固定的，他就可以推测随机结果，通过Token校验。苹果采用的硬件级真随机熵源就能很好应对这种攻击。