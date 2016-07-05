package EGTH::TrackHub::Track;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;
use Readonly;

use Moose;
use namespace::autoclean;

# Attributes
has [qw(
  track
  shortLabel
  )] => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

has [qw(
  type
  longLabel
  bigDataUrl
  html
  )] => (
  is     => 'rw',
  isa    => 'Str',
);

has visibility => (
  is      => 'rw',
  isa     => 'Str|Undef',
  default => 'hide',
);

my @order = qw(
  track
  type
  shortLabel
  longLabel
  bigDataUrl
  html
  visibility
);

has _order => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub { [ @order ] },
);

use overload '""' => 'to_string';

sub _prepare_data {
  my $self = shift;
  
  my %data = (
    track       => $self->track,
    type        => $self->type,
    shortLabel  => $self->shortLabel,
    longLabel   => $self->longLabel,
    bigDataUrl  => $self->bigDataUrl,
    html        => $self->html,
    visibility  => $self->visibility,
  );
  
  return %data;
}
            
sub to_string {
  my $self = shift;
  my @lines;
  
  my %data = $self->_prepare_data;
  
  for my $item (@{ $self->_order }) {
    if (defined $data{$item}) {
      push @lines, $item . ' ' . $data{$item};
    }
  }
  
  return join("\n", @lines) . "\n";
}

__PACKAGE__->meta->make_immutable;
1;

