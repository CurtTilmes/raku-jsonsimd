use NativeCall;
use NativeHelpers::Callback :cb;

my constant LIB = %?RESOURCES<libraries/simdjson>;

INIT die "Missing simdjson library" if LIB.IO ~~ Empty;

my class Element is repr('CPointer') {...}

my class ElementObject {...}
my class ElementArray {...}

my class Elements is repr('CUnion')
{
    has int64   $.i;
    has uint64  $.u;
    has Str     $.s;
    has num64   $.d;
    has bool    $.b;
    has Element $.e;

    method value($type, :$delay)
    {
        given chr($type)
        {
            when '{' { $delay ?? ElementObject.new(element => $!e)
                              !! $!e.object.hash }
            when '[' { $delay ?? ElementArray.new(element => $!e)
                              !! $!e.array.list }
            when '"' { $!s }
            when 'l' { $!i }
            when 'd' { $!d }
            when 't' { so $!b }
            when 'n' { Any }
            when 'u' { $!u < 0 ?? $!u + 1 +< 64 !! $!u }
            default { die "No $_" }
        }
    }
}

# ObjectContent is actually a pointer to an array of these
# The first one has the count of remaining elements
my class ObjectContent is repr('CStruct')
{
    has int32 $.type;
    has Str $.key;
    HAS Elements $.elem;

    constant \struct-size = 24;
    constant \elem-offset = 16;

    method free() is native(LIB) is symbol('objectcontent_free') {}

    method hash(ObjectContent:D: :$delay)
    {
        LEAVE self.free;
        my $base = nativecast(Pointer, self);
        my $elem = nativecast(Elements, Pointer.new($base + elem-offset));
        Hash.new: do for 1..$elem.i
        {
            $base = $base + struct-size;
            my $c = nativecast(ObjectContent, Pointer.new($base));
            $elem = nativecast(Elements, Pointer.new($base + elem-offset));
            $c.key => $elem.value($c.type, :$delay);
        }
    }
}

# ArrayContent is actually a pointer to an array of these
# The first one has the count of remaining elements
my class ArrayContent is repr('CStruct')
{
    has int32 $.type;
    HAS Elements $.elem;

    constant \struct-size = 16;
    constant \elem-offset = 8;

    method free() is native(LIB) is symbol('arraycontent_free') {}

    method list(ArrayContent:D: :$delay)
    {
        LEAVE self.free;
        my $base = nativecast(Pointer, self);
        my $elem = nativecast(Elements, Pointer.new($base + elem-offset));
        do for 1..$elem.i
        {
            $base = $base + struct-size;
            my $c = nativecast(ArrayContent, Pointer.new($base));
            $elem = nativecast(Elements, Pointer.new($base + elem-offset));
            $elem.value($c.type, :$delay)
        }
    }
}

my class ElementObject does Associative[Str,Any] does Iterable
{
    has Element $.element;
    has $!hash;
    has Int $!size;

    method load()     { $!hash = $!element.object.hash(:delay) }

    method Str()      { self.load without $!hash; $!hash.Str }
    method gist()     { self.load without $!hash; $!hash.gist }
    method raku()     { self.load without $!hash; $!hash.raku }
    method keys()     { self.load without $!hash; $!hash.keys }
    method values()   { self.load without $!hash; $!hash.values }
    method pairs()    { self.load without $!hash; $!hash.pairs }
    method kv()       { self.load without $!hash; $!hash.kv }
    method list()     { self.load without $!hash; $!hash.list }
    method iterator() { self.load without $!hash; $!hash.iterator }

    method elems()  { $!hash ?? $!hash.elems !! $!size //= $!element.size }

    method AT-KEY(\key)
    {
        $!hash ?? $!hash.AT-KEY(key) !! $!element.at-key(key).value(:delay)
    }

    method EXISTS-KEY(\key)
    {
        $!hash ?? $!hash.EXISTS-KEY(key) !! $!element.at-key(key).defined
    }

    method object()
    {
        return $!hash = $!element.object.hash unless $!hash;
        for $!hash.kv -> $k,$v
        {
            $!hash{$k} = $v.object if $v ~~ ElementObject|ElementArray;
        }
        $!hash
    }
}

my class ElementArray does Associative[Str,Any] does Positional does Iterable
{
    has Element $.element;
    has List $!list;
    has Int $!size;

    method of() { Any }

    method !loadlist() { $!list = $!element.array.list(:delay) }

    method Str()      { self!loadlist without $!list; $!list.Str }
    method gist()     { self!loadlist without $!list; $!list.gist }
    method raku()     { self!loadlist without $!list; $!list.raku }
    method list()     { self!loadlist without $!list; $!list.list }
    method iterator() { self!loadlist without $!list; $!list.iterator }

    method elems() { $!list ?? $!list.elems !! $!size //= $!element.size }

    method AT-POS(\pos)
    {
        $!list ?? $!list.AT-POS(pos) !! $!element.at(pos).value(:delay)
    }

    method EXISTS-POS(\pos) { 0 <= pos < self.elems }

    method AT-KEY(\key)
    {
        $!element.at-key(key).value(:delay)
    }

    method EXISTS-KEY(\key)
    {
        $!element.at-key(key).defined
    }

    method object()
    {
        return $!list = $!element.array.list unless $!list;
        for $!list.kv -> $k, $v
        {
            $!list[$k] = $v.object if $v ~~ ElementObject|ElementArray;
        }
        $!list
    }
}

my class Element
{
    method type(--> int32) is native(LIB) is symbol('element_type')   {}
    method object(-->ObjectContent) is native(LIB) is symbol('element_object') {}
    method array(--> ArrayContent) is native(LIB) is symbol('element_array')  {}
    method str(--> Str) is native(LIB) is symbol('element_string') {}
    method int(--> int64) is native(LIB) is symbol('element_int')    {}
    method uint(--> uint64) is native(LIB) is symbol('element_uint')   {}
    method num(--> num64) is native(LIB) is symbol('element_double') {}
    method bool(--> bool) is native(LIB) is symbol('element_bool')   {}
    method size(--> size_t) is native(LIB) is symbol('element_size')   {}
    method at-key(Str --> Element) is native(LIB) is symbol('element_at_key') {}
    method at(size_t --> Element) is native(LIB) is symbol('element_at')     {}

    multi method value(Element:U:) { Any }
    multi method value(Element:D: :$delay)
    {
        given chr(self.type)
        {
            when '{' { $delay ?? ElementObject.new(element => self)
                              !! self.object.hash }
            when '[' { $delay ?? ElementArray.new(element => self)
                              !! self.array.list }
            when '"' { self.str }
            when 'l' { self.int }
            when 'u' { my $u = self.uint; $u < 0 ?? $u + 1 +< 64 !! $u }
            when 'd' { self.num }
            when 't' { so self.bool }
            when 'n' { Any }
            default  { die "No $_ ({ord($_)})" }
        }
    }
}

my class Parser is repr('CPointer')
{
    method capacity(--> size_t)
        is native(LIB) is symbol('parser_capacity') {}

    method allocate(size_t, size_t, int32 is rw--> int32)
        is native(LIB) is symbol('parser_allocate') {}

    method load(Str, int32 is rw --> Element)
        is native(LIB) is symbol('parser_load') {}

    method parse(Blob, size_t, int32 is rw --> Element)
        is native(LIB) is symbol('parser_parse') {}

    method parse-many(Blob, size_t, int64, &callback (int64, Element, int32))
        is native(LIB) is symbol('parser_parsemany') {}

    method load-many(Str, int64, &callback (int64, Element, int32))
        is native(LIB) is symbol('parser_loadmany') {}

    method free() is native(LIB) is symbol('parser_free') {}

    submethod DESTROY() { self.free }
}

class X::JSON::simd is Exception
{
    has int32 $.err;

    sub simdjson_errstr(int32 --> Str) is native(LIB) {}

    method message() { simdjson_errstr($!err) }
}

class JSON::simd
{
    has Parser $.parser handles <capacity>;;
    has Bool $.delay;
    has int32 $.err;
    has Channel $.channel;

    sub parser_new(--> Parser) is native(LIB) {}
    sub parser_new_size(size_t --> Parser) is native(LIB) {}

    submethod BUILD(:$!delay = False,
                    Int :$size,
                    Int :$max-depth,
                    Int :$max-capacity)
    {
        $!parser = $max-capacity.defined
                   ?? parser_new_size($max-capacity)
                   !! parser_new;
        die "Failed to allocate parser" unless $!parser;
        self.allocate(:$size, :$max-depth) if $size || $max-depth;
    }

    method throw(JSON::simd:D:) is hidden-from-backtrace
    {
        die X::JSON::simd.new(:$!err)
    }

    method allocate(JSON::simd:D: Int:D :$size = 0xffffffff,
                                  Int:D :$max-depth = 1024)
    {
        $!parser.allocate($size, $max-depth, $!err) == 0 // $.throw;
    }

    method load(JSON::simd:D: $path, :$delay = $!delay)
    {
        my $element = $!parser.load(~$path, $!err) // $.throw;
        $element.value(:$delay)
    }

    multi method parse(JSON::simd:D: Blob:D $blob, :$delay = $!delay)
    {
        my $element = $!parser.parse($blob, $blob.bytes, $!err) // $.throw;
        $element.value(:$delay)
    }

    multi method parse(JSON::simd:D: Str:D $str, |opts)
    {
        samewith $str.encode, |opts
    }

    sub callback(int64 $id, Element $e, int32 $err)
    {
        my $c = cb.lookup($id).channel;
        if $e
        {
            $c.send($e.value)
        }
        else
        {
            $err ?? $c.fail(X::JSON::simd.new(:$err))
                 !! $c.close;
            cb.remove(cb.lookup($id).parser);
        }
    }

    multi method parse-many(JSON::simd:D: Blob:D $blob)
    {
        $!channel = Channel.new;
        cb.store(self, $!parser);
        start $!parser.parse-many($blob, $blob.bytes, cb.id($!parser),&callback);
        $!channel
    }

    multi method parse-many(JSON::simd:D: Str:D $str)
    {
        samewith $str.encode
    }

    method load-many(JSON::simd:D: $path)
    {
        $!channel = Channel.new;
        cb.store(self, $!parser);
        start $!parser.load-many(~$path, cb.id($!parser), &callback);
        $!channel
    }

    sub implementation_name(--> Str) is native(LIB) {}

    method implementation-name() { implementation_name }

    sub implementation_description(--> Str) is native(LIB) {}

    method implementation-description() { implementation_description }
}

sub from-json($str) is export(:subs) { JSON::simd.new.parse($str) }
sub from-json-file($path) is export(:subs) { JSON::simd.new.load($path) }
sub from-json-many($str) is export(:subs) { JSON::simd.new.parse-many($str) }
sub from-json-file-many($path) is export(:subs){JSON::simd.new.load-many($path)}

require JSON::Fast; # Steal to-json from JSON::Fast
EXPORT::subs::<&to-json> = &JSON::Fast::to-json;
