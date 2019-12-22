#!/usr/bin/perl

use v5.012;
use warnings;
use POSIX;
use File::Copy;

use List::Util qw/sum/;

use CharTable;

use constant MOVE_NAMES_START => 0x1c9f29;
use constant MOVE_NAMES_END   => 0x1ca895;

use constant MIN_NAME_LENGTH  => 4;
use constant MAX_NAME_LENGTH  => 12;

my $usage = "usage: $0 <infile> <outfile>\n";

my $inrom = $ARGV[0] or die "please specify a rom file to scramble\n$usage";
my $outrom = $ARGV[1] or die "please specify an output file\n$usage";

my %words;

for my $type ('i', 'P', 'A', 'N', 't') { # hehe iPant
    open my $file, "<", "txt/MOBY_$type.txt";
    $words{$type} = [];
    while (my $w = <$file>) {
        chomp $w;
        push @{$words{$type}}, $w;
    }
}

# Pokemon moves follow a few formulas:
# i = intransitive-verb (recover, yawn, dig, growl, etc)
# t = transitive verb (tackle, pound, curse, reflect, etc)
# N = noun (growth, confusion, spore, thief, etc)
# A = adjective (psychic, toxic, softboiled, swift, etc -- rare)
# AN = adjective noun (icy wind, dynamic punch, seismic toss, quick attack, etc)
# Nt = noun transitive-verb (milk drink, rock throw, skill swap, arm thrust, etc)
# NN = noun noun (comet punch, thunder wave, rock tomb, etc)
# Ni = noun intransitive-verb (dragon/petal/etc dance, sleep talk, defense curl, etc -- v rare)
# iP/tP = verb preposition (beat up, take down, slack off, lock on, etc -- v rare)

my @formulas = qw(tP AN AN AN AN Nt Nt Nt Nt Nt Nt t t t t t t i i i i i i N N N N N N A A NN NN NN NN Ni);

sub make_move {
    my $result;
    my $formula;

    $formula = $formulas[rand @formulas];

    do {
        $result = '';

        for my $piece (split //, $formula) {
            # pick a random word from that category of formula
            $result .= $words{$piece}[rand @{$words{$piece}}] . ' ';
        }

        chop $result;
    } while ((length $result) > MAX_NAME_LENGTH or (length $result) < MIN_NAME_LENGTH);

    return (uc $result);
}

my @newmoves;

do {
    @newmoves = ();
    push @newmoves, make_move for 1..251;
} while ((sum map { (length $_) + 1 } @newmoves) > MOVE_NAMES_END - MOVE_NAMES_START);

say for @newmoves;

# so... the way it determines what the name of a given move is, is that it
# literally just starts at the address of the first move and reads forward,
# counting string terminators, until it finds the nth move name.
#
# this means as long as the names aren't too long, they're pretty easy to
# put in -- no repointing necessary

my @binary_newmoves = map { pack "C*", (map { $Table::Byte{$_} } split //, $_), 0x50 } @newmoves;

copy($inrom, $outrom) or die "Couldn't create output ROM file $outrom: $!.\n";

open my $OUT, "+<", $outrom;
binmode($OUT);

seek $OUT, MOVE_NAMES_START, 0;

for my $bin_name (@binary_newmoves) {
    print { $OUT } $bin_name;
}
