use Test;
use JSON::simd;

plan 9;

isa-ok my $json = JSON::simd.new, JSON::simd, 'create object';

isa-ok my $c = $json.parse-many('[1,2,3][4,5,6]'), 'Channel', 'parse-many';

is-deeply $c.receive, (1,2,3), 'item 1';
is-deeply $c.receive, (4,5,6), 'item 2';

throws-like { $c.receive }, X::Channel::ReceiveOnClosed, 'closed';

isa-ok $c = $json.parse-many("5 6 4x"), 'Channel', 'parse-many bad';

is $c.receive, 5, 'good item 1';
is $c.receive, 6, 'good item 2';

throws-like { $c.receive }, X::JSON::simd,
    message => 'Problem while parsing a number', 'bad item 3';

done-testing;
