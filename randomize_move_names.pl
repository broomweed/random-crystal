#!/usr/bin/perl

use v5.012;
use warnings;
use POSIX;
use File::Copy;

use List::Util qw/sum/;

use CharTable;

use constant MOVE_NAMES_START => 0x1c9f29;
use constant MOVE_NAMES_END   => 0x1ca895;

my $usage = "usage: $0 <infile> <outfile> [--weird=<number>]\n" .
            "       weird: amplify uncommon name parts. default is 0.5";

my $inrom = $ARGV[0] or die "please specify a rom file to scramble\n$usage";
my $outrom = $ARGV[1] or die "please specify an output file\n$usage";

my %words;

my %used;

for my $type ('P', '!', 'N', 'A', 'v', 'i', 't', 'V') {
    open my $file, "<", "txt/MOBY_$type.txt";
    $words{$type} = [];
    while (my $w = <$file>) {
        chomp $w;
        push @{$words{$type}}, $w unless exists $used{$w};
        #$used{$w} = 1 unless $type eq 't' or $type eq 'i';
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

my @formulas = qw(iP AN AN AN AN Nt Nt Nt Nt Nt Nt t t t t t t i i i i i i N N N N N N A A NN NN NN NN Ni);

sub make_move {
    my $result;
    my $formula;

    do {
        $formula = $formulas[rand @formulas];
        my $count = 0;
        do {
            $count ++;
            $result = '';

            for my $piece (split //, $formula) {
                # pick a random word from that category of formula
                $result .= $words{$piece}[rand @{$words{$piece}}] . ' ';
            }

            chop $result;
        } while (((length $result) > 12 or (length $result) < 4) and $count < 50);
    } while ((length $result) > 12 or (length $result) < 4);

    return (uc $result);
}

my @newmoves;

do {
    @newmoves = ();
    push @newmoves, make_move for 1..251;
    #say "total length: ", (sum map { (length $_) + 1 } @newmoves), " vs ", MOVE_NAMES_END - MOVE_NAMES_START;
} while ((sum map { (length $_) + 1 } @newmoves) > MOVE_NAMES_END - MOVE_NAMES_START);

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
