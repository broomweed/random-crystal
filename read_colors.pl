#!/usr/bin/perl

# Outputs the color palettes of each pokemon into html, for easy viewing

use v5.012;

my @pokes = do {
    open my $file, "<", 'pokemon.txt' or die "can't get pokemon names";
    <$file>;
};

open my $rom, "+<", $ARGV[0] or die "can't open rom";

say "<html><body><table>";

for my $index (0..250) {
    seek $rom, 0xa8d6 + $index * 8, 0;

    read $rom, my $bin, 8;
    my @nums = unpack "SSSS", $bin;

    say "<tr style='height: 10px'><td style='min-width:150px;'>", $index+1, ". ", $pokes[$index], "</td>";
    for my $num (@nums) {
        my $b = ($num >> 10) & 0x1f;
        my $g = ($num >>  5) & 0x1f;
        my $r = ($num >>  0) & 0x1f;

        $r *= 8;
        $g *= 8;
        $b *= 8;

        say sprintf "<td style='background-color:#%02X%02X%02X;' width='20px'></td>", $r, $g, $b;
    }
    say "</tr>";
}

say "</table></body></html>";
