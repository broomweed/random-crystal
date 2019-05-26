#!/usr/bin/perl

use v5.010;
use File::Copy;
use List::Util qw/shuffle/;

use constant COLOR_START => 0xa8d6;

my $inrom = $ARGV[0] or die "please specify a rom file to scramble; usage: $0 <infile> <outfile>";
my $outrom = $ARGV[1] or die "please specify an output file; usage: $0 <infile> <outfile>";

copy($inrom, $outrom) or die "Couldn't create output ROM file $outrom: $!.\n";

my @colors = ([], [], [], []);

{
    open my $IN, "+<", $inrom;
    binmode $IN;

    for my $index (0..251) {
        for my $color (0..3) {
            seek $IN, COLOR_START + $index * 8 + $color * 2, 0;
            read $IN, my $bin, 2;
            my $val = unpack "S", $bin;
            push @{$colors[$color]}, $val;
        }
    }
}

for my $color (0..3) {
    $colors[$color] = [shuffle @{$colors[$color]}];
}


{
    open my $OUT, "+<", $outrom;
    binmode $OUT;

    for my $index (0..251) {
        for my $color (0..3) {
            my $byte = shift @{$colors[$color]};

            seek $OUT, COLOR_START + $index * 8 + $color * 2, 0;
            print { $OUT } pack "S", $byte;
        }
    }
}
