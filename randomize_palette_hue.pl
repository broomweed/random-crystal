#!/usr/bin/perl

use v5.012;
use File::Copy;
use List::Util qw/max min any/;
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
    print $index + 1, " Y: ";
    for my $num (@nums) {
        #my ($h, $s, $v) = rgb_to_hsv(fifteen_to_rgb($num));
        #my $orig_h = $h;

        #my $shiftamt = rand() * 330 + 15;
        #$h += $shiftamt;
        #$h += $hueshift;
        #$h %= 360;

        my ($y, $i, $q) = rgb_to_yiq(fifteen_to_rgb($num));

        printf "rgb: %02x%02x%02x ; ", fifteen_to_rgb($num);

        printf "yiq: %.3f %.3f %.3f ; ", $y, $i, $q;

        my ($newI, $newQ, @newrgb);
        do {
            my $angle = rand() * 6.28;
            ($newI, $newQ) = (rand() ** (2/3) * sin $angle, rand() ** (2/3) * cos $angle);
            @newrgb = yiq_to_rgb($y, $newI, $newQ);
        } while (any { $_ < 0 or $_ > 255 } @newrgb or dist($i, $q, $newI, $newQ) < 0.15);
        printf "newRGB: %02x%02x%02x; %d %d %d\n", @newrgb, @newrgb;

        printf "yiq of newrgb: %.3f %.3f %.3f\n", rgb_to_yiq(@newrgb);

        my $newcolor = rgb_to_fifteen(@newrgb);
        push @newnums, $newcolor;
    }
    print "\n";

    seek $rom, 0xa8d6 + $index * 8, 0;
    print { $rom } pack "SSSS", @newnums;
}

sub dist {
    my ($a, $b, $c, $d) = @_;
    return sqrt (($a - $c) ** 2 + ($b - $d) ** 2);
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

    my $sR = floor($r / 8);
    my $sG = floor($g / 8);
    my $sB = floor($b / 8);

    return (($sB & 0x1f) << 10) | (($sG & 0x1f) << 5) | ($sR & 0x1f);
}

# we'll use YIQ to extract the luma value (Y), so we (hopefully) end up with
# colors of a similar brightness to the original
sub rgb_to_yiq {
    my ($r, $g, $b) = @_;

    $r /= 255; $g /= 255; $b /= 255;

    return (0.299  * $r + 0.587  * $g + 0.114  * $b,
            0.5959 * $r - 0.2746 * $g - 0.3213 * $b,
            0.2115 * $r - 0.5227 * $g + 0.3112 * $b);
}

sub yiq_to_rgb {
    sub yiq_conversion {
        my ($y, $i, $q) = @_;
        return ($y + 0.956 * $i + 0.619 * $q,
                $y - 0.272 * $i - 0.647 * $q,
                $y - 1.106 * $i + 1.703 * $q);
    }

    my @result = yiq_conversion @_;
    return map { 255 * $_ } @result;
}

# ported from: https://www.cs.rit.edu/~ncs/color/t_convert.html
sub rgb_to_hsv {
    my ($r, $g, $b) = @_;

    $r /= 255; $g /= 255; $b /= 255;

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
    sub hsv_conversion {
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

    my ($r, $g, $b) = hsv_conversion @_;
    return ($r * 255, $g * 255, $b * 255);
}
