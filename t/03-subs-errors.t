use Test;
use JSON::simd :subs;

plan 3;

throws-like { from-json('') }, X::JSON::simd,
    message => /Empty/, 'Empty';

throws-like { from-json('{') }, X::JSON::simd,
    message => /improper ' ' structure/, 'Improper structure';

throws-like { from-json('17x') }, X::JSON::simd,
    message => 'Problem while parsing a number', 'Bad number';

done-testing;
