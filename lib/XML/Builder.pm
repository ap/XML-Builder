package XML::Builder;

use strict;
use Encode ();
use Scalar::Util ();
use Carp ();

use Object::Tiny qw( nsmap pfxmap default_ns encoding );

our $VERSION = '1.0001';
$VERSION = eval $VERSION;

sub fragment_class { 'XML::Builder::Fragment' }
sub unsafe_class   { 'XML::Builder::Fragment::Unsafe' }
sub tag_class      { 'XML::Builder::Fragment::Tag' }
sub tagleaf_class  { 'XML::Builder::Fragment::TagLeaf' }
sub doc_class      { 'XML::Builder::Fragment::Document' }

sub new {
	return bless {
		encoding => 'us-ascii',
		nsmap    => {},
		counter  => 1,
		pfxmap   => {},
		@_
	}, shift;
}

sub register_ns {
	my $self = shift;
	my ( $uri, $pfx ) = @_;

	my $nsmap = $self->nsmap;

	$uri = $self->stringify( $uri );

	if ( exists $nsmap->{ $uri } ) {
		my $registered_pfx = $nsmap->{ $uri };

		Carp::croak( "Namespace '$uri' being bound to '$pfx' is already bound to '$registered_pfx'" )
			if defined $pfx and $pfx ne $registered_pfx;

		return $self->pfxmap->{ $registered_pfx };
	}

	if ( not defined $pfx ) {
		if ( $uri eq '' and not exists $self->pfxmap->{ '' } ) {
			return $self->register_ns( '', '' );
		}

		my $letter = ( $uri =~ m!([[:alpha:]])[^/]*/?\z! ) ? lc $1 : 'ns';
		do { $pfx = $letter . $self->{ 'counter' }++ } while exists $self->pfxmap->{ $pfx };
	}

	# FIXME needs proper validity check per XML TR
	Carp::croak( "Invalid namespace prefix '$pfx'" )
		if length $pfx and $pfx !~ /[\w-]/;

	my $ns = XML::Builder::QName->new( $self, $uri );

	$self->{ 'default_ns' } = $uri if '' eq $pfx;
	$nsmap->{ $uri } = $pfx;
	$self->pfxmap->{ $pfx } = $ns;

	return $ns;
}

sub prefix_for_uri {
	my $self = shift;
	my ( $uri ) = @_;
	$self->register_ns( $uri ) if not exists $self->nsmap->{ $uri };
	return $self->nsmap->{ $uri };
}

sub null_ns { shift->register_ns( '', '' ) }

sub parse_qname {
	my $self = shift;
	my ( $name ) = @_;

	my $uri = '';

	if ( 'ARRAY' eq ref $name ) {
		( $name, $uri ) = @$name;
		$uri = '' if not defined $uri;
	}
	elsif ( $name =~ s/\A\{([^}]+)\}// ) {
		$uri = $1;
	}

	return ( $name, $uri );
}

sub qname {
	my $self = shift;
	my ( $name, $uri, $is_attr ) = @_;

	# attributes without a prefix are in the null namespace,
	# not in the default namespace, so never put a prefix on
	# attributes in the null namespace
	my $pfx = ( '' eq $uri and $is_attr ) ? '' : $self->prefix_for_uri( $uri );

	return '' eq $pfx ? $name : "$pfx:$name";
}

sub nsmap_to_attr {
	my $self = shift;
	my ( $attr ) = @_;

	$attr ||= {};

	while ( my ( $uri, $pfx ) = each %{ $self->nsmap } ) {
		next if '' eq $pfx;
		$attr->{ 'xmlns:' . $pfx } = $uri;
	}

	# make sure to always declare the default NS (if not bound to a URI, by
	# explicitly undefining it) to allow embedding the XML easily without
	# having to parse the fragment
	# [in 5.10: $attr->{ xmlns } = $map->default_ns // '';]
	$attr->{ xmlns } = $self->default_ns;
	$attr->{ xmlns } .= '';

	return $attr;
}

my $is_raw_hash = sub {
	my ( $scalar ) = @_;
	return 'HASH' eq ref $scalar and not Scalar::Util::blessed $scalar;
};

my $merge_hash = sub {
	my ( $cur, $new ) = @_;
	@{ $cur }{ keys %$new } = values %$new;
	while ( my ( $k, $v ) = each %$cur ) {
		delete $cur->{ $k } if not defined $v;
	}
};

sub tag {
	my $self = shift;

	if ( 'SCALAR' eq ref $_[0] and 'foreach' eq ${$_[0]} ) {
		shift @_; # throw away
		return $self->tag_foreach( @_ );
	}

	my $name = shift;
	my ( $name, $uri ) = $self->parse_qname( $name );

	if ( not @_ ) {
		return $self->tagleaf_class->new(
			name    => $name,
			ns      => $uri,
			builder => $self,
		);
	}

	my $attr = {};
	$merge_hash->( $attr, shift @_ ) if $is_raw_hash->( $_[0] );

	return $self->tag_class->new(
		name    => $name,
		ns      => $uri,
		attr    => $attr,
		content => [ map $self->render( $_ ), @_ ],
		builder => $self,
	);
}

sub tag_foreach {
	my $self = shift;
	my $name = shift;

	my ( $name, $uri ) = $self->parse_qname( $name );

	if ( not @_ ) {
		return $self->tagleaf_class->new(
			name    => $name,
			ns      => $uri,
			builder => $self,
		);
	}

	my $attr = {};
	my @out  = ();

	do {
		$merge_hash->( $attr, shift @_ ) if $is_raw_hash->( $_[0] );
		my $content = ( not $is_raw_hash->( $_[0] ) ) ? shift : undef;
		push @out, $self->tag_class->new(
			name    => $name,
			ns      => $uri,
			attr    => {%$attr},
			content => $self->render( $content ),
			builder => $self,
		);
	} while @_;

	return $self->fragment_class->new( builder => $self, content => \@out )
		if @out > 1 and not wantarray;

	return @out[ 0 .. $#out ];
}

sub root {
	my $self = shift;
	my ( $tag ) = @_;
	return $self->doc_class->adopt( $tag );
}

sub preamble { qq(<?xml version="1.0" encoding="${\shift->encoding}"?>\n) }

sub document {
	my $self = shift;
	return $self->preamble . $self->root( @_ );
}

sub unsafe {
	my $self = shift;
	my ( $string ) = @_;
	return $self->unsafe_class->new( builder => $self, content => $string );
}

sub render {
	my $self = shift;
	my ( $r ) = @_;

	my $t = ref $r;

	if ( $t && Scalar::Util::blessed $r ) {
		return $r if not $r->isa( $self->fragment_class );

		return $r if $self == $r->builder;

		Carp::croak( 'Cannot merge XML::Builder fragments built with different namespace maps' )
			if $r->depends_ns_scope;

		my ( $self_enc, $r_enc ) = map { lc $_->encoding } $self, $r->builder;
		return $r
			if $self_enc eq $r_enc
			# be more permissive: ASCII is one-way compatible with UTF-8 and Latin-1
			or 'us-ascii' eq $r_enc and grep { $_ eq $self_enc } 'utf-8', 'iso-8859-1';

		Carp::croak(
			'Cannot merge XML::Builder fragments'
			. ' with incompatible encodings'
			. " (have $self_enc, fragment has $r_enc)"
		);
	}

	return $self->tag( @$r ) if 'ARRAY' eq $t;

	Carp::croak( 'Unhandled type of reference ', $t ) if $t;

	return $r;
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
		# using eval instead of closures to avoid __ANON__
		eval 'sub '.$subname.' {
			my $self = shift;
			my $str = $self->stringify( shift );
			$str =~ s{ '.$specials_rx.' }{ $XML_NCR{$1} }gex;
			return Encode::encode $self->encoding, $str, Encode::HTMLCREF;
		}';
	}
}

sub encode {
	my $self = shift;
	my $str = $self->stringify( shift );
	return Encode::encode $self->encoding, $str, Encode::HTMLCREF;
}

sub stringify {
	my $self = shift;
	my ( $thing ) = @_;

	return if not defined $thing;

	return $thing if not Scalar::Util::blessed $thing;

	my $conv = $thing->can( 'as_string' ) || overload::Method( $thing, '""' );
	return $conv->( $thing ) if $conv;

	Carp::croak( 'Unstringifiable object ', $thing );
}

sub flatten_cdata {
	my $self = shift;
	my ( $str ) = @_;
	$str =~ s{<!\[CDATA\[(.*?)]]>}{ $self->escape_text( $1 ) }gse;
	Carp::croak( 'Incomplete CDATA section' ) if -1 < index $str, '<![CDATA[';
	return $str;
}

#######################################################################

package XML::Builder::QName;

use overload '""' => sub { $_[0]{'uri'} };

sub AUTOLOAD {
	our $AUTOLOAD =~ /.*::(.*)/;
	splice @_, 1, 0, $1;
	goto &_tag;
}

sub new {
	my $class = shift;
	my %self;
	@self{ qw( builder uri ) } = @_;
	return bless \%self, $class;
}

sub _tag {
	my $self = shift;
	my $name = shift;
	my ( $builder, $uri ) = @{$self}{ qw( builder uri ) };
	return $builder->tag( [ $name, $uri ], @_ );
}

#######################################################################

package XML::Builder::Fragment;

use Object::Tiny qw( builder content );

sub depends_ns_scope { 0 }

sub new {
	my $class = shift;
	my $self = bless { @_ }, $class;
	my $content = \$self->{'content'};

	$$content = [ defined $$content ? $$content : () ]
		if 'ARRAY' ne ref $$content
		or Scalar::Util::blessed $$content;

	@$$content = map { ref $_ ? $_->flatten : $_ } @$$content;

	return $self;
}

sub as_string {
	my $self = shift;
	my $builder = $self->builder;
	return join '', map { ref $_ ? $_->as_string : $builder->escape_text( $_ ) } @{ $self->content };
}

sub flatten {
	my $self = shift;
	return @{ $self->content };
}

#######################################################################

package XML::Builder::Fragment::Unsafe;

use parent -norequire => 'XML::Builder::Fragment';

sub as_string { map { defined $_ ? @$_ : undef } shift->content }
sub flatten { shift }

#######################################################################

package XML::Builder::Fragment::Tag;

use parent -norequire => 'XML::Builder::Fragment';
use Object::Tiny qw( name ns attr );

sub depends_ns_scope { 1 }

sub as_string {
	my $self = shift;

	my $builder = $self->builder;
	my $qname   = $builder->qname( $self->name, $self->ns );
	my $attr    = $self->attr || {};

	my $tag = join ' ', $qname,
		map { sprintf '%s="%s"', $builder->qname( $builder->parse_qname( $_ ), 1 ), $builder->escape_attr( $attr->{ $_ } ) }
		sort keys %$attr;

	my $content = @{ $self->content } ? $self->SUPER::as_string : undef;
	return defined $content
		? "<$tag>$content</$qname>"
		: "<$tag/>";
}

sub append {
	my $self = shift;
	return $self->builder->fragment_class->new(
		builder => $self->builder,
		content => [ $self, $self->builder->render( @_ ) ],
	);
}

sub flatten { shift }

#######################################################################

package XML::Builder::Fragment::TagLeaf;

use parent -norequire => 'XML::Builder::Fragment::Tag';
use overload '""' => 'as_clarkname';

sub foreach {
	my $self = shift;
	return $self->builder->tag_foreach( [ $self->name, $self->ns ], @_ );
}

sub as_clarkname {
	my $self = shift;
	my $name = $self->name;
	my $ns = $self->ns;
	return $name if not defined $ns;
	return "{$ns}$name";
}

#######################################################################

package XML::Builder::Fragment::Document;

use parent -norequire => 'XML::Builder::Fragment::Tag';
use overload '""' => 'as_string';

sub depends_ns_scope { 0 }

sub adopt {
	my $class = shift;
	my ( $obj ) = @_;
	$obj->{ 'attr' } ||= {};
	$obj->builder->nsmap_to_attr( $obj->attr );
	return bless $obj, $class;
}

#######################################################################

1;
