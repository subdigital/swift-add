# swift-add

Easily add Swift packages from the command line!

> Note: This is a work-in-progress. Somethings may not work.
> Please file issues if you run into any problems.

## Example

```
$ swift add johnsundell/Files

Added Files (4.2.0) from https://github.com/johnsundell/Files
```

## Installation

Clone the repository and build:

```
$ git clone https://github.com/subdigital/swift-add
$ swift build
```

When you run `swift add`, the Xcode toolchain will look for a binary
named `swift-add` somewhere in your path. So we need to copy the built
binary into your path somewhere:

```
cp .build/debug/swift-add /usr/local/bin/
```

Now you're ready!

## Usage

Add packages by GitHub short url:

```
$ swift add sparrowcode/SPSafeSymbols
```

Specify which products to integrate into your main target:

```
$ swift add firebase/firebase-ios-sdk -p FirebaseAnalytics -p FirebaseAuth
```

## Roadmap

- [x] add with GitHub short repo
- [ ] add with name (will search Swift Package Index)
- [ ] specify exact version, tag, branch

## LICENSE

MIT License

