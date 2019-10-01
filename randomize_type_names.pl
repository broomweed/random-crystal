#!/usr/bin/perl

use strict;
use warnings;
use v5.010;

use List::Util qw/uniq shuffle sum/;
use Fcntl qw/SEEK_SET SEEK_CUR/;
use File::Copy;
use CharTable;

use constant TYPE_NAME_PTR_START => 0x5097b;
use constant PADDED_TYPE_NAME_START => 0x40fed;

die "usage: $0 <infile> <outfile>\n" unless @ARGV == 2;

my ($infilename, $outfilename) = @ARGV;

open my $inrom, "<", $infilename or die "couldn't open input rom: $!\n";

# First, we want to read in the original list of types.
# For some reason, the list of types goes up to 27.
# But a lot of them are just duplicates.
# I guess they left room to expand?
my @typename_entries = ();
for my $i (0..27) {
    seek $inrom, TYPE_NAME_PTR_START + $i * 2, 0;
    read $inrom, my $data, 2;
    # read the pointer as an unsigned 16-bit short ('v')
    my $offset = unpack "v", $data;
    push @typename_entries, $offset;
}

# Remove the duplicates for now.
my @typename_offsets = uniq @typename_entries;

# Build a list of the original types.
my @oldtypes = ();
for my $offset (@typename_offsets) {
    # seek to that location in the rom bank
    seek $inrom, $offset + 0x4c000, SEEK_SET;
    # Read at this offset until we reach 0x50 (string terminator)
    my $char;
    my @bytes = ();
    do {
        read $inrom, my $byte, 1;
        $char = unpack "C", $byte;
        push @bytes, $char;
    } while ($char != 0x50);
    pop @bytes; # remove string terminator

    # convert to a string and put in list
    my $typename = join '', map { $Table::Char{$_} } @bytes;
    push @oldtypes, $typename;
}

close $inrom;

# Ok, now we can figure out how much space we have to work with.
# (When we generate new type names, we don't want to exceed
# the space the original names took up!)
# To figure this out, we sum the lengths of each type name,
# plus one for the string terminator
my $space = sum map { 1 + length $_ } @oldtypes;

say "Original type names: ", (join ", ", @oldtypes);
say "We have $space bytes to fit our new type names into.";

# Now it's time to generate a new set of funny type names.
# We read them from types.txt which I assembled based on
# an edited version of the noun and adjective lists from
# https://github.com/janester/mad_libs.
# I hope they don't mind.
# But you can edit types.txt if you want your own list of
# types instead.
open my $typefile, "<", "types.txt" or die "couldn't open auxiliary file 'types.txt': $!\n";

my @vocab = <$typefile>;
chomp @vocab;

# Remove any duplicates, find ones w/ max length 8, and shuffle them
@vocab = grep { length $_ <= 8 } uniq @vocab;

# Find the index of the ??? type, if it exists. (So we don't replace
# it with something else -- this gives us a few more bytes to work with
# usually.)
my $question_index = -1;
for my $i (0..$#oldtypes) {
    if ($oldtypes[$i] eq "???") {
        $question_index = $i;
        last;
    }
}

# Same with BIRD type, but here we'll replace it with an empty string.
my $bird_index = -1;
for my $i (0..$#oldtypes) {
    if ($oldtypes[$i] eq "BIRD" or $oldtypes[$i] eq "") {
        $bird_index = $i;
        last;
    }
}

# Take some random types and check if they fit into the allotted space.
# (Yes, there are 17 types in gen 2. But $#oldtypes == 18? So there are 19?
# Turns out, there's also a ??? type (used only for the move Curse) and an
# unused BIRD type (returning from gen. 1 for... backwards compatibility,
# I guess?) We could probably change BIRD to an empty string to gain a few
# more bytes. Future work?
# Also, I've chosen to preserve the ??? type. I don't know if that's the right
# choice. I guess the right choice depends on whether or not we're randomizing
# type effects as well, if stuff is going to end up being ??? type, etc.
my @newtypes;
do {
    @newtypes = @{[ shuffle @vocab ]}[0..$#oldtypes];
    $newtypes[$question_index] = "???";
    $newtypes[$bird_index] = "";
} while ((sum map { 1 + length $_ } @newtypes) > $space);

# We convert all the types to uppercase to match the original game.
@newtypes = map { uc } @newtypes;

# Print them out for good measure
for my $i (0..$#newtypes) {
    say $oldtypes[$i], " -> ", $newtypes[$i];
}

# Now we have to compute the new pointers for type names.
# First we just compute their offsets relative to the first string
# (what was formerly NORMAL gets address 0, etc.)
my @type_small_offsets = ();
my $curr_offset = 0;
for my $tp (@newtypes) {
    push @type_small_offsets, $curr_offset;
    $curr_offset += (length $tp) + 1;
}

# Now, we find the lowest pointer value and add that to all those offset values.
# We put them into a map so that the old offsets map to these new ones.
# I dunno if this is common perl knowledge, but I love this trick, so what we're
# doing here is assigning a list of values to a 'slice' of a hash determined by
# a list of keys. This results in assigning each key to each value one-to-one
# (because we're assigning a list to a list.) Handy!
my $low_ptr = $typename_entries[0];
my %type_offset_map = ();
@type_offset_map{@typename_offsets} = map { $_ + $low_ptr } @type_small_offsets;

# Now that we have the map, we can just run it over the non-uniq-ified list
# and it'll magically handle all the duplicate entries without us having to
# do anything!
# Then we have to convert the pointers back into 16-bit little-endian integers.
my $ptr_bytes = join '', map { pack "v", $_ } map { $type_offset_map{$_} } @typename_entries;

# Now we have the pointers to the new strings, but we still have to get the
# actual new strings. Fortunately this is not so hard.

# Convert the strings to the pokemon character table format, add the string
# terminators, and join them together into a nice happy binary blob.
my $type_bytes = join '',
                 map { $_ . pack "C", 0x50 }
                 map { join '', map { pack "C", $Table::Byte{$_} } split //, $_ }
                 @newtypes;

# Lastly, there's another set of type names that are all space-padded to 8
# characters. Not sure where they're used but should probably take care
# of that.
sub pad_spaces {
    my ($name) = @_;
    # Spaces get added to beginning and end, until the type name has
    # 8 characters. If the name is an odd length, we prefer adding
    # a space to the end.
    while (length $name < 8) {
        $name = $name . ' ';
        last if length $name == 8;
        $name = ' ' . $name;
    }

    return $name;
}

# Same as above, but we pad the type names with spaces first, and we don't
# include the ??? or BIRD type here
my $padded_types = join '',
                   map { $_ . pack "C", 0x50 }
                   map { join '', map { pack "C", $Table::Byte{$_} } split //, $_ }
                   map { pad_spaces $_ }
                   grep { $_ ne "???" and $_ ne "" }
                   @newtypes;

# Now it's time to write the changes to the rom.
# First we create a copy of the original rom.
copy($infilename, $outfilename);

open my $outrom, "+<", $outfilename or die "Couldn't open $outfilename: $!\n";

seek $outrom, TYPE_NAME_PTR_START, 0;
print { $outrom } $ptr_bytes;

seek $outrom, $low_ptr + 0x4c000, SEEK_SET;
print { $outrom } $type_bytes;

seek $outrom, PADDED_TYPE_NAME_START, SEEK_SET;
print { $outrom } $padded_types;

close $outrom;
