package EGTH::TrackHub::SubTrack;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
extends 'EGTH::TrackHub::Track';
use namespace::autoclean;

# Attributes
has parent => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

# Rewrite parent subs
sub BUILD {
  my $self = shift;
  push @{ $self->_order }, 'parent'
    if not grep { $_ eq 'parent' } @{ $self->_order };
}

sub _prepare_data {
  my $self = shift;
  my %data = $self->SUPER::_prepare_data;
  $data{parent} = $self->parent;
  return %data;
}

__PACKAGE__->meta->make_immutable;
1;

