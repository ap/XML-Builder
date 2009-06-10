package XML::Builder;

use strict;
use Encode ();
use Scalar::Util qw( blessed );
use overload '""', 'as_string';

our $VERSION = '1.0000';

sub croak { require Carp; goto &Carp::croak }

our $stringify = sub {
	my ( $thing ) = @_;

	return if not defined $thing;

	return $thing if not blessed $thing;

	my $conv = $thing->can( 'as_string' ) || overload::Method( $thing, '""' );
	return $conv->( $thing ) if $conv;

	croak 'Unstringifiable object ', $thing;
};

our $is_hash = sub {
	my ( $scalar ) = @_;
	return 'HASH' eq ref $scalar and not blessed $scalar;
};

sub new {
	return bless {
		encoding            => 'us-ascii',
		content             => undef,
		ns                  => {}, # CRUCIAL: must be shared by all clones!
		have_default_ns => !1,
		@_
	}, shift
}

sub clone {
	my $self = shift;
	return bless { %$self, @_ }, ref $self;
}

sub register_ns {
	my $self = shift;
	my ( $pfx, $uri ) = @_;

	$uri = $stringify->( $uri );

	croak "Invalid namespace binding prefix '$pfx'"
		if length $pfx and $pfx =~ /[\w-]/;

	croak "Namespace '$uri' being bound to '$pfx' is already bound to '$self->{ ns }{ $uri }'"
		if exists $self->{ ns }{ $uri };

	$self->{ ns }{ $uri } = $pfx;
	$self->{ have_default_ns } ||= ( '' eq $pfx );

	return $self;
}

sub find_or_create_prefix {
	my $self = shift;
	my ( $uri ) = @_;

	my $ns = $self->{ ns };

	if ( not exists $ns->{ $uri } ) {
		my $letter = ( $uri =~ m!([[:alpha:]])[^/]*/?\z! ) ? lc $1 : 'ns';
		$ns->{ $uri } = $letter . ( 1 + keys %$ns );
	}

	return $ns->{ $uri };
}

sub clark_to_qname {
	my $self = shift;
	my ( $qname, $is_attr ) = @_;

	if ( not $qname =~ s/\A\{// ) {
		return $qname if $is_attr or not $self->{ have_default_ns };
		croak "Cannot create element '$qname' outside a namespace when a default namespace is registered";
	}

	my ( $uri, $localname ) = split /\}/, $qname, 2;
	my $pfx = $self->find_or_create_prefix( $uri );
	return '' eq $pfx ? $localname : $pfx . ':' . $localname;
}

sub tag {
	my $self = shift;
	my $name = shift;

	my $qname = $self->clark_to_qname( $name );
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
				map { $self->clark_to_qname( $_, 1 ) . '="' . $self->escape_attr( $attr{ $_ } ) . '"' }
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

	my $default_ns;

	while ( my ( $uri, $pfx ) = each %{ $self->{ ns } } ) {
		if ( '' eq $pfx ) { $default_ns = $uri; next }
		$attr->{ 'xmlns:' . $pfx } = $uri;
	}

	# if no default NS is declared, explicitly undefine it; this allows
	# embedding as a fragment into scopes that do have a default namespace
	$attr->{ xmlns } = defined $default_ns ? $default_ns : '';

	return $self->tag( $name, $attr, \@_ );
}

sub render {
	my $self = shift;
	my ( $r ) = @_;

	my $type = ref $r;
	my $is_obj = $type && blessed $r;

	# make sure to retain objectness when called by user
	return $r if $is_obj and $r->isa( __PACKAGE__ );

	return
		  'ARRAY' eq $type                     ? join( '', map { (defined) ? $self->render( $_ ) : () } @$r )
		: 'REF' eq $type && 'ARRAY' eq ref $$r ? scalar $self->tag( @$$r )
		: $type && ! $is_obj                   ? croak( 'Unknown type of reference ', $type )
		: defined $r                           ? $self->escape_text( $stringify->( $r ) )
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
	$str =~ s{<!\[CDATA\[(.*?)]]>}{ $self->escape_text( $1 ) }ge;
	croak 'Incomplete CDATA section' if -1 < index $str, "<![CDATA[";
	return $str;
}

# in 5.10:
#sub as_string { $_[0]->{ content } // () }
sub as_string { my $c = $_[0]->{ content }; defined $c ? $c : () }

{
package XML::Builder::NS;
use overload '""' => sub { ${$_[0]} };
sub new { bless \do { my $copy = $_[1] }, $_[0] }
sub AUTOLOAD { our $AUTOLOAD =~ /.*::(.*)/; '{' . ${$_[0]} . '}' . $1 }
}

1;
