use Test;
use JSON::simd;

plan 3;

isa-ok my $json = JSON::simd.new, JSON::simd, 'create object';

ok $json.implementation-name, 'implementation-name';
ok $json.implementation-description, 'implementation-description';

done-testing;
