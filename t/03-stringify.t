use strict;
use XML::Builder;
use Test::More tests => 5;

isa_ok my $x = XML::Builder->new, 'XML::Builder';

{
package SomeClass;
sub new { bless {}, shift }

package SomeClass::AsStr;
our @ISA = 'SomeClass';
sub as_string { 'an object' }

package SomeClass::Overload;
our @ISA = 'SomeClass';
use overload '""' => sub { 'no really' };

package SomeClass::AsStr::Overload;
our @ISA = 'SomeClass::AsStr';
use overload '""' => sub { 'ignore me' };
}

my $obj1 = SomeClass->new;
eval { $x->tag( 'p', $obj1 ) };
like $@, qr/^Unstringifiable object SomeClass=/, 'reject random objects';

my $obj2 = SomeClass::AsStr->new;
is $x->tag( 'p', $obj2 ), '<p>an object</p>', 'explicit object stringification';

my $obj3 = SomeClass::Overload->new;
is $x->tag( 'p', $obj3 ), '<p>no really</p>', 'implicit object stringification';

my $obj4 = SomeClass::AsStr::Overload->new;
is $x->tag( 'p', $obj4 ), '<p>an object</p>', 'explicit object stringification preferred';
