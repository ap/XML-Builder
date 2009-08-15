my $croak = sub { require Carp; goto &Carp::croak }; # file scope!

package XML::Builder;

use strict;
use Encode ();
use Scalar::Util ();

our $VERSION = '1.0001';
$VERSION = eval $VERSION;

# XXX probably should be replaced with Params::Util?
our $is_hash = sub {
	my ( $scalar ) = @_;
	return 'HASH' eq ref $scalar and not Scalar::Util::blessed $scalar;
};

sub new {
	return bless {
		encoding => 'us-ascii',
		content  => undef,
		nsmap    => XML::Builder::NSMap->new(), # CRUCIAL: must be shared by all clones!
		@_
	}, shift
}

sub clone {
	my $self = shift;
	return bless { %$self, @_ }, ref $self;
}

sub nsmap      { $_[0]->{ nsmap } }
sub as_string  { $_[0]->{ content } }
sub encoding   { $_[0]->{ encoding } }
sub root_class { 'XML::Builder::Document' }

sub register_ns {
	my $self = shift;
	my ( $uri, $pfx ) = @_;
	my $_uri = $self->stringify( $uri );
	$self->nsmap->register( $_uri, $pfx );
	return XML::Builder::NS->new( $_uri );
}

sub tag {
	my $self = shift;
	my $name = shift;

	my $qname = $self->nsmap->qname( $name );
	my $tag   = $qname;
	my %attr  = ();
	my @out   = ();

	do {
		# are there attributes to process?
		if ( @_ and $is_hash->( $_[0] ) ) {
			my $new_attr = shift @_;
			while ( my ( $k, $v ) = each %$new_attr ) { # merge
				defined $v ?$attr{ $k } = $v : delete $attr{ $k };
			}
			# re-render tag
			$tag = join ' ', $qname,
				map { sprintf '%s="%s"', $self->nsmap->qname( $_, 1 ), $self->escape_attr( $attr{ $_ } ) }
				sort keys %attr;
		}

		# what content will this tag have, if any?
		my $content;
		if ( @_ and not $is_hash->( $_[0] ) ) {
			$content = shift;
			$content = $self->render( $content ) if defined $content;
		}

		# assemble markup fragment
		push @out, defined $content ? "<$tag>$content</$qname>" : "<$tag/>";

	} while @_;

	return wantarray
		? map { $self->clone( content => $_ ) } @out
		: $self->clone( content => join '', @out );
}

sub root {
	my $self = shift;
	my $name = shift;
	my $attr = $self->nsmap->to_attr( $is_hash->( $_[0] ) ? shift : {} );
	return $self->root_class->adopt( $self->tag( $name, $attr, \@_ ) );
}

sub preamble { qq(<?xml version="1.0" encoding="${\shift->encoding}"?>\n) }

sub document {
	my $self = shift;
	return $self->preamble . $self->root( @_ );
}

sub render {
	my $self = shift;
	my ( $r ) = @_;

	my $t          = ref $r;
	my $is_obj     = $t && Scalar::Util::blessed $r;
	my $is_arefref = 'REF' eq $t && 'ARRAY' eq ref $$r;

	if ( $is_obj and $r->isa( __PACKAGE__ ) ) {
		my ( $self_enc, $r_enc ) = map { lc } $self->encoding, $r->encoding;

		$croak->( 'Cannot merge XML::Builder fragments built with different namespace maps' )
			if $self->nsmap != $r->nsmap
			and not $r->isa( $self->root_class );

		return $r->as_string
			if $self_enc eq $r_enc
			# be more permissive: ASCII is one-way compatible with UTF-8 and Latin-1
			or 'us-ascii' eq $r_enc and grep { $_ eq $self_enc } 'utf-8', 'iso-8859-1';

		$croak->(
			'Cannot merge XML::Builder fragments'
			. ' with incompatible encodings'
			. " (have $self_enc, fragment has $r_enc)"
		);
	}

	return
		  'ARRAY' eq $t   ? ( join '', map $self->render( $_ ), grep defined, @$r )
		: $is_arefref     ? scalar $self->tag( @$$r )
		: $t && ! $is_obj ? $croak->( 'Unknown type of reference ', $t )
		: defined $r      ? $self->escape_text( $self->stringify( $r ) )
		: ();
}

{
	my %XML_NCR = map eval "qq[$_]", qw(
		\xA &#10;  \xD &#13;
		&   &amp;  <   &lt;   > &gt;
		"   &#34;  '   &#39;
	);

	my %type = (
		escape_text => qr/([<>&'"])/,
		escape_attr => qr/([<>&'"\xA\xD])/,
	);

	while ( my ( $subname, $specials_rx ) = each %type ) {
		my $slot = do { no strict 'refs'; \*{ $subname } };
		*$slot = sub {
			my $self = shift;
			my $str = $self->stringify( shift );
			$str =~ s{ $specials_rx }{ $XML_NCR{$1} }gex;
			return Encode::encode $self->{ 'encoding' }, $str, Encode::HTMLCREF;
		}
	}
}

sub stringify {
	my $self = shift;
	my ( $thing ) = @_;

	return if not defined $thing;

	return $thing if not Scalar::Util::blessed $thing;

	my $conv = $thing->can( 'as_string' ) || overload::Method( $thing, '""' );
	return $conv->( $thing ) if $conv;

	$croak->( 'Unstringifiable object ', $thing );
}

sub flatten_cdata {
	my $self = shift;
	my ( $str ) = @_;
	$str =~ s{<!\[CDATA\[(.*?)]]>}{ $self->escape_text( $1 ) }gse;
	$croak->( 'Incomplete CDATA section' ) if -1 < index $str, '<![CDATA[';
	return $str;
}


#######################################################################

package XML::Builder::Document;

use parent 'XML::Builder';
use overload '""' => 'as_string';

sub adopt {
	my $class = shift;
	my ( $obj ) = @_;
	return bless $obj, $class;
}

#######################################################################

package XML::Builder::NSMap;

sub new { bless { '' => '', '-' => '' }, shift }

sub default { $_[0]->{ '-' } }

sub register {
	my $self = shift;
	my ( $uri, $pfx ) = @_;

	if ( defined $pfx ) {
		# FIXME needs proper validity check per XML TR
		$croak->( "Invalid namespace prefix '$pfx'" )
			if length $pfx and $pfx !~ /[\w-]/;

		$croak->( "Namespace '$uri' being bound to '$pfx' is already bound to '$self->{ $uri }'" )
			if exists $self->{ $uri };
	}
	else {
		my $letter = ( $uri =~ m!([[:alpha:]])[^/]*/?\z! ) ? lc $1 : 'ns';
		$pfx = $letter . ( 1 + keys %$self );
	}

	$self->{ $uri } = $pfx;
	$self->{ '-' } = $uri if '' eq $pfx;

	return $self;
}

sub prefix_for {
	my $self = shift;
	my ( $uri ) = @_;
	$self->register( $uri ) if not exists $self->{ $uri };
	return $self->{ $uri };
}

sub qname {
	my $self = shift;
	my ( $name, $is_attr ) = @_;

	my $uri = my $pfx = '';

	if ( 'ARRAY' eq ref $name ) {
		( $uri, $name ) = @$name;
	}
	elsif ( $name =~ s/\A\{([^}]+)\}// ) {
		$uri = $1;
	}

	# attributes without a prefix are in the null namespace,
	# not in the default namespace, so never put a prefix on
	# attributes in the null namespace
	$pfx = $self->prefix_for( $uri )
		unless '' eq $uri and $is_attr;

	return '' eq $pfx ? $name : "$pfx:$name";
}

sub to_attr {
	my $self = shift;
	my ( $attr ) = @_;

	$attr //= {};

	while ( my ( $uri, $pfx ) = each %{ $self } ) {
		next if '-' eq $uri or '' eq $pfx;
		$attr->{ 'xmlns:' . $pfx } = $uri;
	}

	# make sure to always declare the default NS (if not bound to a URI, by
	# explicitly undefining it) to allow embedding the XML easily without
	# having to parse the fragment
	# [in 5.10: $attr->{ xmlns } = $map->default // '';]
	$attr->{ xmlns } = $self->default;
	$attr->{ xmlns } .= '';

	return $attr;
}


#######################################################################

package XML::Builder::NS;

use overload '""' => sub { ${$_[0]} };

sub new { bless \do { my $uri = $_[1] }, $_[0] }

sub qname { '{' . ${$_[0]} . '}' . $_[1] }

sub qpair { my $self = shift; [ $$self, $_[0] ] }

sub AUTOLOAD { our $AUTOLOAD =~ /.*::(.*)/; shift->qpair( $1 ) }


1;
