#!/usr/bin/perl

use v5.012;

use List::Util qw/max shuffle/;
use File::Copy;
use Data::Dumper;

use constant DEX_PTR_START => 0x44378;

my @DEX_OFFSETS = (0x17c000, 0x1b4000, 0x1c8000, 0x1cc000);

my @INITIAL_OFFSETS = (0x5695, 0x4000, 0x4000, 0x4000);

my %CHARTABLE = (
    '@' => 0xF5, # female symbol
    '*' => 0xEF, # male symbol
    '%' => 0xEA, # é
    '^' => 0xD0, # 'd
    '.' => 0xF2,
    '-' => 0xE3,
    ' ' => 0x7F,
    '|' => 0x50,
);

my $byte = 0x80;

for my $i ('A'..'Z', '(', ')', ':', ';', '[', ']', 'a'..'z') {
    $CHARTABLE{$i} = $byte;
    $byte ++;
}

$byte = 0xF6;

for my $i ('0', '1'..'9') {
    $CHARTABLE{$i} = $byte;
    $byte ++;
}

my %REV;
for my $k (keys %CHARTABLE) {
    $REV{$CHARTABLE{$k}} = $k;
}

# Extract pokedex info
my $inrom = $ARGV[0] or die "please specify a rom file to scramble; usage: $0 <infile> <outfile>\n";
my $outrom = $ARGV[1] or die "please specify an output file; usage: $0 <infile> <outfile>\n";

open my $ROM, "+<", $inrom or die "couldn't open rom: $!.\n";
binmode $ROM;

my @shortdex;
my @longdex;
my @extradex;

# First grab all the pokedex entries out.
for my $quadrant (0..3) {
    # the pokedex is in 4 quarters (due to gbc memory banks), so 64 pokemon each,
    # these are the offsets of the pointers for each one.
    my $dex_offset = $DEX_OFFSETS[$quadrant];
    for my $qindex (0..63) {
        my $index = $quadrant * 64 + $qindex;
        last if $index > 250;

        seek $ROM, DEX_PTR_START + $index * 2, 0;

        # Read 2 bytes that point to dex entry
        read $ROM, my $bin, 2;

        # Compute location & jump to dex entry
        my $ptr = $dex_offset + (unpack "S", $bin);
        seek $ROM, $ptr, 0;

        # Read short desc. until 0x50 (string terminator)
        my $shortdesc = '';
        while (1) {
            read $ROM, my $byte, 1;
            last if (unpack "C", $byte) == 0x50;
            $shortdesc .= $byte;
        }

        # the 4 bytes that are like the footprint or sth I think (?)
        read $ROM, my $extra, 4;
        push @extradex, $extra;

        # Now read long desc. until 0x50
        my $longdesc = '';
        my $npages = 0;
        while (1) {
            read $ROM, my $byte, 1;
            if ((unpack "C", $byte) == 0x50) {
                $npages ++;
                last if $npages == 2;
            }
            $longdesc .= $byte;
        }

        # Put this entry into the dex.
        push @shortdex, $shortdesc;
        push @longdex, $longdesc;
    }
}

close $ROM;

sub zip {
    return map { [ $_[0][$_], $_[1][$_] ] } 0..$#{$_[0]};
}

# Shuffle.
@longdex = shuffle @longdex;
@shortdex = shuffle @shortdex;
@extradex = shuffle @extradex;

# Create output file
copy($inrom, $outrom) or die "Couldn't create output ROM file $outrom: $!.\n";

open my $OUT, "+<", $outrom or die "couldn't open output file: $!.\n";
binmode $OUT;

# Put the pokedex entries back in.
for my $quadrant (0..3) {
    my $amt_written = $INITIAL_OFFSETS[$quadrant];
    my $dex_offset = $DEX_OFFSETS[$quadrant];

    for my $qindex (0..63) {
        my $index = $quadrant * 64 + $qindex;
        last if $index > 250;

        my $position = $dex_offset + $amt_written;

        seek $OUT, $position, 0;

        print { $OUT } $shortdex[$index];
        print { $OUT } pack "C", 0x50;
        print { $OUT } $extradex[$index];
        print { $OUT } $longdex[$index];
        print { $OUT } pack "C", 0x50;

        seek $OUT, DEX_PTR_START + $index * 2, 0;

        print { $OUT } pack "S", $amt_written;

        $amt_written += (length $shortdex[$index]) + (length $longdex[$index]) + 6;
    }
}
