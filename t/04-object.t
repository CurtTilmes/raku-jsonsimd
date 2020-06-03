use Test;
use JSON::simd :subs;

plan 7;

isa-ok my $json = JSON::simd.new, JSON::simd, 'create object';

isa-ok my $x = $json.parse('{ "a" : "b" }', :delay), 'ElementObject', 'parse';

is-deeply $x.object, { :a<b> }, 'correct result';

is-deeply $json.parse('[7, -17, 0, "this", true, false, 2e86, null, [1,2,3],
                      {"a" : "b"}]'),
    (7, -17, 0, 'this', True, False, 2e86, Any, (1,2,3), {:a<b>}), 'array';

isa-ok my $a = $json.parse('[1,2,3]', :delay), 'ElementArray', 'delay array';

is $a[1], 2, '[1]';

is $a<1>, 2, 'associative too';

done-testing;
