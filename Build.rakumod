#!/usr/bin/env raku
use Native::Compile;

my $winurl = 'https://www.dropbox.com/s/s9c9kqjqcfxj1iq/simdjson-0.1.dll?dl=1';
my $winhash = '3eb26a6d73ee73490f6bdb1d7cfa704cf8cc0da9f0bdb4b7ea2e6353d1e892ca';

my $macurl = 'https://www.dropbox.com/s/nwe4ga9f4bop7z9/libsimdjson-0.1.dylib?dl=1';
my $machash = 'b3b4921ffa3c4e5aa919b7cdacddb7c69a5267d2ca146c36a68ffab55484e375';

class Build
{
    multi method build($dir, :$verbose, :$dryrun)
    {
        build :lib<simdjson>, :$dir, :$verbose, :$dryrun, :clean,
              :src<src/simdjson.cpp src/simdjson-cinterface.cpp>,
              extra-cxxflags => $*DISTRO.is-win ?? '' !! '-std=c++17',
              fallback =>
              [
                  %(
                      os => 'windows',
                      url => $winurl,
                      hash => $winhash
                  ),
                  %(
                      os => 'darwin',
                      url => $macurl,
                      hash => $machash
                  )
              ]
    }
}
