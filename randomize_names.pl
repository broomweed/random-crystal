#!/usr/bin/perl

use v5.010;
use List::Util qw/sum shuffle/;
use Data::Dumper;
use File::Copy;
use MIME::Base64;

use constant NAMES_START => 0x053384;
use constant MAX_NAME_LEN => 10;

my @words;

{
    open my $wordfile, "<", "pokemon.txt";

    @words = <$wordfile>;
    chomp @words;

    say "Read @{[scalar @words]} words";
}

my %stats;

my %counts;

# Find commonness of each cluster
for my $word (@words) {
    $word = lc $word;

    $word =~ s/é/%/g;
    $word =~ s/♀/@/g;
    $word =~ s/♂/*/g;
    $word =~ s/’d/\^/g;

    #next if $word =~ /[^a-z]/;

    # Things we can't really handle
    next if $word =~ /qu/;

    my @wordparts = split /([aeiouy%]+)/, $word;

    @wordparts = grep { length $_ > 0 } @wordparts;

    for my $i (0..$#wordparts) {
        my $piece = $wordparts[$i];
        my $prevpiece = $i > 0 ? $wordparts[$i-1] : '';
        my $nextpiece = $i < $#wordparts ? $wordparts[$i+1] : '';

        my $type = ($piece =~ /[aeiouy%]/ ? "v" : "c") x length $piece;
        my $prevtype = ($prevpiece =~ /[aeiouy%]/ ? "v" : "c") x length $prevpiece;
        my $nexttype = ($nextpiece =~ /[aeiouy%]/ ? "v" : "c") x length $nextpiece;

        my $position;
        if ($i == 0) {
            $position = "initial:$type$nexttype";
        } elsif ($i == $#wordparts) {
            $position = "final:$prevtype$type";
        } else {
            $position = "medial:$prevtype$type$nexttype";
        }
        $stats{$position}{$piece} ++;
    }
}

my @newwords = ();

# Create random words
for my $word (@words) {
    $word = lc $word;
    chomp $word;

    my @wordparts = split /([aeiouy%]+)/, $word;

    @wordparts = grep { length $_ > 0 } @wordparts;

    my $newword = '';

    for my $i (0..$#wordparts) {
        my $piece = $wordparts[$i];
        my $prevpiece = $i > 0 ? $wordparts[$i-1] : '';
        my $nextpiece = $i < $#wordparts ? $wordparts[$i+1] : '';

        my $type = ($piece =~ /[aeiouy%]/ ? "v" : "c") x length $piece;
        my $prevtype = ($prevpiece =~ /[aeiouy%]/ ? "v" : "c") x length $prevpiece;
        my $nexttype = ($nextpiece =~ /[aeiouy%]/ ? "v" : "c") x length $nextpiece;

        my $position;
        if ($i == 0) {
            $position = "initial:$type$nexttype";
        } elsif ($i == $#wordparts) {
            $position = "final:$prevtype$type";
        } else {
            $position = "medial:$prevtype$type$nexttype";
        }
        $newword .= weight_rand(%{$stats{$position}});
    }

    push @newwords, $newword;
}

# Weighted random
sub weight_rand {
    my %items = @_;

    my $total = sum values %items;

    for my $item (keys %items) {
        if (rand() < $items{$item} / $total) {
            return $item;
        }

        $total -= $items{$item};
    }
}

# insert into ROM
my %CHARTABLE = (
    '@' => 0xF5, # female symbol
    '*' => 0xEF, # male symbol
    '%' => 0xEA, # é
    '^' => 0xD0, # 'd
    '.' => 0xF2,
    '-' => 0xE3,
    ' ' => 0x7F,
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

my $inrom = $ARGV[0] or die "please specify a rom file to scramble; usage: $0 <infile> <outfile>";
my $outrom = $ARGV[1] or die "please specify an output file; usage: $0 <infile> <outfile>";

copy($inrom, $outrom) or die "Couldn't create output ROM file $outrom: $!.\n";

open my $OUT, "+<", $outrom;
binmode($OUT);

sub capitalize_after {
    my ($char, @words) = @_;
    return map { join $char, @$_ } map { [ map { ucfirst $_ } @$_ ] } map { [ split $char, $_ ] } @words;
}

@newwords = grep { length $_ <= MAX_NAME_LEN } @newwords;
@newwords = capitalize_after ' ', @newwords;
@newwords = capitalize_after '-', @newwords;

# some bad words aren't very funny, like racial/etc slurs
# but i don't want people seeing such words on my github page
# so i just base64'd them. you can decode them if you're curious which words i banned
my $badwords = decode_base64('ZmFnfG5pZ3xjdW50fHRhcmQ=');
@newwords = grep { $_ !~ /$badwords/i } @newwords;

@newwords = grep { $_ !~ /tr$/ } @newwords; # 'feraligatr' is dumb due to text limits
@newwords = grep { $_ !~ /ncc/ } @newwords; # 'minccino' etc don't work well here
@newwords = grep { $_ !~ /rrl/ } @newwords; # likewise 'purrloin'
@newwords = grep { $_ !~ /:/ } @newwords; # 'type: null' I think is weird (up to you I guess)

@newwords = shuffle @newwords;

for my $index (0..255) {
    my @bytes = map { $CHARTABLE{$_} } split '', $newwords[$index];

    push @bytes, 0x50 while @bytes < MAX_NAME_LEN;

    say ((sprintf "%".MAX_NAME_LEN."s", $newwords[$index]), " => ", (join ':', map { sprintf "%02X", $_ } @bytes));

    seek $OUT, NAMES_START + $index * MAX_NAME_LEN, 0;
    print { $OUT } pack "C*", @bytes;
}
