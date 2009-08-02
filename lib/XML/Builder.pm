package XML::Builder;

use strict;
use Encode ();
use Scalar::Util ();

our $VERSION = '1.0000';

sub croak { require Carp; goto &Carp::croak }

our $stringify = sub {
	my ( $thing ) = @_;

	return if not defined $thing;

	return $thing if not Scalar::Util::blessed $thing;

	my $conv = $thing->can( 'as_string' ) || overload::Method( $thing, '""' );
	return $conv->( $thing ) if $conv;

	croak 'Unstringifiable object ', $thing;
};

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
	my $clone = bless { %$self, @_ }, ref $self;
	return $clone;
}

sub nsmap { $_[0]->{ nsmap } }

sub register_ns {
	my $self = shift;
	my ( $pfx, $uri ) = @_;
	my $_uri = $stringify->( $uri );
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
	my $attr = $is_hash->( $_[0] ) ? shift : {};

	my $map = $self->nsmap;

	for my $uri ( $map->list ) {
		my $pfx = $map->prefix_for( $uri );
		$attr->{ 'xmlns:' . $pfx } = $uri
			if '' ne $pfx;
	}

	# if no default NS is declared, explicitly undefine it; this allows
	# embedding as a fragment into scopes that do have a default namespace
	# [in 5.10: $attr->{ xmlns } = $map->default // '';]
	$attr->{ xmlns } = $map->default;
	$attr->{ xmlns } .= '';

	return $self->tag( $name, $attr, \@_ );
}

sub render {
	my $self = shift;
	my ( $r ) = @_;

	my $t          = ref $r;
	my $is_obj     = $t && Scalar::Util::blessed $r;
	my $is_arefref = 'REF' eq $t && 'ARRAY' eq ref $$r;

	return $r->as_string if $is_obj and $r->isa( __PACKAGE__ );

	return
		  'ARRAY' eq $t   ? ( join '', map $self->render( $_ ), grep defined, @$r )
		: $is_arefref     ? scalar $self->tag( @$$r )
		: $t && ! $is_obj ? ( croak 'Unknown type of reference ', $t )
		: defined $r      ? $self->escape_text( $stringify->( $r ) )
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
			my $str = $stringify->( shift );
			$str =~ s{ $specials_rx }{ $XML_NCR{$1} }gex;
			return Encode::encode $self->{ 'encoding' }, $str, Encode::HTMLCREF;
		}
	}
}

sub flatten_cdata {
	my $self = shift;
	my ( $str ) = @_;
	$str =~ s{<!\[CDATA\[(.*?)]]>}{ $self->escape_text( $1 ) }gse;
	croak 'Incomplete CDATA section' if -1 < index $str, '<![CDATA[';
	return $str;
}

# in 5.10:
#sub as_string { $_[0]->{ content } // () }
sub as_string { my $c = $_[0]->{ content }; defined $c ? $c : () }



#######################################################################

package XML::Builder::NSMap;

sub croak { require Carp; goto &Carp::croak }

sub new { bless {}, shift }

sub default { $_[0]->{ '-' } }

sub register {
	my $self = shift;
	my ( $uri, $pfx ) = @_;

	if ( defined $pfx ) {
		# FIXME needs proper validity check per XML TR
		croak "Invalid namespace prefix '$pfx'"
			if length $pfx and $pfx !~ /[\w-]/;

		croak "Namespace '$uri' being bound to '$pfx' is already bound to '$self->{ $uri }'"
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

sub list { grep '-' ne $_, keys %{ $_[0] } }

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


#######################################################################

package XML::Builder::NS;

use overload '""' => sub { ${$_[0]} };

sub new { bless \do { my $uri = $_[1] }, $_[0] }

sub qname { '{' . ${$_[0]} . '}' . $_[1] }

sub qpair { my $self = shift; [ $$self, @_ ] }

sub AUTOLOAD { our $AUTOLOAD =~ /.*::(.*)/; shift->qpair( $1 ) }


1;
