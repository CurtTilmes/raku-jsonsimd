use Test;
use JSON::simd :subs;

plan 15;

isa-ok my $x = from-json('{ "a" : "b" }'), Hash, 'from-json';

is-deeply $x, { :a<b> }, 'correct result';

is from-json('7'), 7, 'int';

is from-json('-12'), -12, 'negative int';

is from-json('0'), 0, 'zero';

is from-json('"this"'), 'this', 'string';

is from-json('true'), True, 'True';

is from-json('false'), False, 'False';

is from-json('2e86'), 2e86, 'double';

is from-json('9223372036854775807'), 9223372036854775807, 'max int64';

is from-json('9223372036854775808'), 9223372036854775808, 'uint64';

is from-json('null'), Any, 'null';

is-deeply from-json('[1,2,3]'), (1,2,3), 'array';

is-deeply from-json('{"a" : "b" }'), {:a<b>}, 'object';

is-deeply from-json('[7, -17, 0, "this", true, false, 2e86, null, [1,2,3],
                      {"a" : "b"}]'),
    (7, -17, 0, 'this', True, False, 2e86, Any, (1,2,3), {:a<b>}), 'array';

done-testing;
