use Test::More tests => 4;

ok( $] >= 5.008001, "Your perl ($]) is new enough" );
use_ok( 'XML::Builder' ) or BAIL_OUT( 'testing pointless if the module won\'t even load' );
diag( "Testing XML::Builder $XML::Builder::VERSION" );

isa_ok my $xb = XML::Builder->new, 'XML::Builder';
isa_ok my $x  = $xb->null_ns, 'XML::Builder::NS::QNameFactory';
