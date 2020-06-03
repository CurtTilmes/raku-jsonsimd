# JSON::simd - Raku bindings for simdjson

## Introduction

A [Raku](https://raku.org/) interface to
[simdjson](https://simdjson.org/), a library for parsing JSON.

While the `simdjson` library itself is blazing fast at parsing JSON,
transferring all the data it has parsed into Raku data structures
isn't actually much faster than parsing with other Raku libraries such
as [JSON::Fast](https://github.com/timo/json_fast).

In some situations, especially if you don't need all the data,
`JSON::simd` can offer some advantages.

## Subroutines

Drop in replacement for `JSON::Fast`:

```
use JSON::simd :subs;

$x = from-json '{ "a" : "b" }';          # Parse a string
$x = from-json-file 'file.json';         # Read from a file
```

As an added bonus, this also imports `to-json` from `JSON::Fast`,
which works exactly as usual.

## Object oriented use

`JSON::simd` also supports object usage.  This allocates the parser
and its memory buffers only once, reusing for each document parsed.

```
use JSON::simd;

my $json = JSON::simd.new;

my $x = $json.parse: '{ "a" : "b" }';     # Parse a string
my $x = $json.load: 'file.json';          # Read from a file
```

These methods act identically to the above subs.

## Delayed object access

The `:delay` option performs the entire parse (extremely fast), but
doesn't actually pull all the data out of the parser object into Raku.
Instead it seamlessly replaces Objects and Arrays with placeholder
objects.  The placeholder objects act (almost) identically to the
traditional ones, and pull in data as it is accessed.  This can slow
things down if you walk the entire data structure, causing everything
to be pulled in, but if you access only portions of the data, it can
be dramatically faster.

```
my $x = $json.parse: '...json stuff...', :delay;
say $x<somekey>[17]<another>;
```

If you always want objects delayed, you can use the `:delay` option on
the inital object creation:

```
my json = JSON::simd.new(:delay);         # Set default parse to delay
$x = $json.parse(...);                    # This one will get delayed
$x = $json.parse(..., :!delay);           # This one will not delay
```

`simdjson` also supports [JSON Pointer](https://tools.ietf.org/html/rfc6901)
 access through both the Object and Array placeholder objects.

Instead of calling `$x<somekey>[17]<another>`, the same result will be
returned with `$x<somekey/17/another>` without actually retrieving the
intermediate objects/arrays in full.

**IMPORTANT -- CAVEAT EMPTOR**

One drawback of delayed access is that the actual data remains in the
parser, precluding its further use until all data access is complete.
If another JSON document is parsed by the same parser followed by
access to the previous placeholder objects, things are likely to
crash.

## Multiple

The simdjson library also supports multithreaded JSON streaming
through a large file containing many smaller JSON documents in either
[ndjson](http://ndjson.org/) or [JSON lines](http://jsonlines.org/)
format. If your JSON documents all contain arrays or objects, they can
be concatenated without whitespace. The concatenated file has no size
restrictions (including larger than 4GB), though each individual
document must be less than 4GB.

These are implemented by returning a `Channel`.  As long as JSON
objects are successfully parsed, they are sent through the Channel.
If parsing encounters an error, a `Failure` is sent through the
channel which will be thrown as an `Exception`.

```
for $json.parse-many('[1,2,3][4,5,6]').list -> $record {
   ...Do something with each $record...
}
```

There is also a `.load-many` method, and subs for `from-json-many` and
`from-json-file-many`.

There is no delay option for the 'many' parsing.  All objects are
completely received and separate from the parser object.

## Maximum depth of parsing

By default the maximum depth of JSON data structures is 1024.  This
can be set manually with the `:max-depth` option on intial object
creation, or with the `.allocate` method.

```
my $json = JSON::simd.new(max-depth => 16);
$json.allocate(max-depth => 32);
```

## Manual capacity allocation

The simdjson library automatically expands its memory capacity when
larger documents are parsed, so that you don't unexpectedly fail. In a
short process that reads a bunch of files and then exits, this works
pretty flawlessly.

You can query the current capacity like this:
```
say $json.capacity;
```

For better control of memory in long running processes, the simdjson
library lets you adjust your allocation strategy to prevent your
server from growing without bound.

```
my $json = JSON::simd.new(max-capacity => 1_000_0000);
```

You can also manually set the allocation (setting max-capacity to 0
prevents it from ever auto-expanding):

```
my $json = JSON::simd.new(max-capacity => 0, size => 1_000_000);
$json.allocate(size => 2_000_000);  # Manually reset capacity;
```

More information is available at [Server Loops: Long-Running Processes and Memory Capacity](https://github.com/simdjson/simdjson/blob/master/doc/performance.md#server-loops-long-running-processes-and-memory-capacity).

## Implementation

`simdjson` has highly tuned implementations for various processor
capabilities.  When first run, they test the processor and choose the
best implementation.  If you are curious, you can see which
implementation is active:

```
say JSON::simd.implmentation-name, JSON::simd.implementation-description;
```

# Installation

This library is very dependent on 64-bit architectures and should only
be installed on a 64-bit OS.

Building the C++ library requires a C++ compiler.  The commands below
may or may not help you install one.

For Windows and MacOS, pre-built libraries are also available as fallbacks
if the build doesn't find a compiler.

If you have trouble installing, please file an issue with as many
details about your setup as possible.

* Debian/Ubuntu

```
apt update
apt install -y g++
zef install JSON::simd
```

If you get g++ compiling errors, it may be due to an older compiler.
You can try this and then the commands above:

```
echo deb http://ftp.us.debian.org/debian testing main contrib non-free >> /etc/apt/sources.list
```

* Alpine Linux

```
apt add --update --no-cache g++
zef install JSON::simd
```

* CentOS

```
yum install -y gcc-c++
zef install JSON::simd
```

# License

The original `simdjson` code is available under Apache License 2.0.

The additional interface code and Raku bindings are Copyright © 2020
United States Government as represented by the Administrator, National
Aeronautics and Space Administration. No Copyright is claimed in the
United States under Title 17, U.S. Code.  All Other Rights Reserved.
