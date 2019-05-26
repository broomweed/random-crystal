#!/usr/bin/perl

use v5.012;
use File::Copy;
use List::Util qw/max min/;
use POSIX;

my $inrom = $ARGV[0] or die "please specify a rom file to scramble; usage: $0 <infile> <outfile>\n";
my $outrom = $ARGV[1] or die "please specify an output file; usage: $0 <infile> <outfile>\n";

copy($inrom, $outrom) or die "Couldn't create output ROM file $outrom: $!.\n";

open my $rom, "+<", $outrom or die "can't open rom after creating output copy: $!\n";

for my $index (0..250) {
    seek $rom, 0xa8d6 + $index * 8, 0;

    read $rom, my $bin, 8;
    my @nums = unpack "SSSS", $bin;

    my @newnums;
    #my $hueshift = rand() * 360;
    for my $num (@nums) {
        my ($h, $s, $v) = rgb_to_hsv(fifteen_to_rgb($num));
        my $orig_h = $h;

        my $shiftamt = rand() * 330 + 15;
        say $shiftamt;
        $h += $shiftamt;
        #$h += $hueshift;
        $h %= 360;

        #say sprintf "%02X %02X %02X", hsv_to_rgb($h, $s, $v);
        my $newcolor = rgb_to_fifteen(hsv_to_rgb($h, $s, $v));
        push @newnums, $newcolor;
    }

    seek $rom, 0xa8d6 + $index * 8, 0;
    print {$rom} pack "SSSS", @newnums;
}

sub fifteen_to_rgb {
    my ($num) = @_;

    my $b = ($num >> 10) & 0x1f;
    my $g = ($num >>  5) & 0x1f;
    my $r = ($num >>  0) & 0x1f;

    $r *= 8;
    $g *= 8;
    $b *= 8;

    return ($r, $g, $b);
}

sub rgb_to_fifteen {
    my ($r, $g, $b) = @_;

    my $sR = ceil($r / 8);
    my $sG = ceil($g / 8);
    my $sB = ceil($b / 8);

    return (($sB & 0x1f) << 10) | (($sG & 0x1f) << 5) | ($sR & 0x1f);
}

# ported from: https://www.cs.rit.edu/~ncs/color/t_convert.html
sub rgb_to_hsv {
    my ($r, $g, $b) = @_;

    $r /= 256; $g /= 256; $b /= 256;

    my ($h, $s, $v);

    my $min = min($r, $g, $b);
    my $max = max($r, $g, $b);

    $v = $max;

    my $delta = $max - $min;

    if ($max != 0) {
        $s = $delta / $max;
    } else {
        # they're all 0 so black (undefined h)
        return (-1, 0, -1);
    }

    if ($delta == 0) {
        # grey (undefined h)
        return (-1, 0, $r);
    }

    if ($r == $max) {
        # between yellow and magenta
        $h = ($g - $b) / $delta;
    } elsif ($g == $max) {
        # between cyan and yellow
        $h = 2 + ($b - $r) / $delta;
    } else {
        # between cyan and magenta
        $h = 4 + ($r - $g) / $delta;
    }

    $h *= 60;
    if ($h < 0) {
        $h += 360;
    }

    return ($h, $s, $v);
}

sub hsv_to_rgb {
    sub conversion {
        my ($h, $s, $v) = @_;

        if ($s == 0) {
            # grey
            return ($v, $v, $v);
        }

        $h /= 60;

        my $i = floor($h);

        my $f = $h - $i;

        my $p = $v * (1 - $s);
        my $q = $v * (1 - $s * $f);
        my $t = $v * (1 - $s * (1 - $f));

        if ($i == 0) {
            return ($v, $t, $p);
        } elsif ($i == 1) {
            return ($q, $v, $p);
        } elsif ($i == 2) {
            return ($p, $v, $t);
        } elsif ($i == 3) {
            return ($p, $q, $v);
        } elsif ($i == 4) {
            return ($t, $p, $v);
        } elsif ($i == 5) {
            return ($v, $p, $q);
        }
    }

    my ($r, $g, $b) = conversion @_;
    return ($r * 256, $g * 256, $b * 256);
}
