use strict;
use warnings;

package Table;

# %Table::Byte gives the byte for a given char
our %Byte = (
    '@' => 0xF5, # female symbol
    '*' => 0xEF, # male symbol
    'é' => 0xEA,
   "'d" => 0xD0,
   "'l" => 0xD1,
   "'m" => 0xD2,
   "'r" => 0xD3,
   "'s" => 0xD4,
   "'t" => 0xD5,
   "'v" => 0xD6,
    "'" => 0xE0,
 'POK%' => 0x54,
    '.' => 0xF2,
    ',' => 0xF4,
   "\n" => 0x4E,
    '-' => 0xE3,
    ' ' => 0x7F,
  "\\0" => 0x50,
    '.' => 0xE8,
    "?" => 0xE6,
    "!" => 0xE7,
  "..." => 0x75,
);

my $byte = 0x80;

for my $i ('A'..'Z', '(', ')', ':', ';', '[', ']', 'a'..'z') {
    $Byte{$i} = $byte;
    $byte ++;
}

$byte = 0xF6;

for my $i ('0', '1'..'9') {
    $Byte{$i} = $byte;
    $byte ++;
}

# %Table::Char gives the char for a given byte
our %Char;
for my $k (keys %Byte) {
    $Char{$Byte{$k}} = $k;
}

1;
