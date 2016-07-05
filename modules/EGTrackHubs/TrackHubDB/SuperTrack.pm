package EGTrackHubs::TrackHubDB::SuperTrack;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
extends 'EGTrackHubs::TrackHubDB::Track';
use EGTrackHubs::TrackHubDB::SubTrack;
use namespace::autoclean;

# Attributes
has '+visibility' => (
  default => undef,
);

has show => (
  is      => 'rw',
  isa     => 'Bool',
  default => 1,
);

has sub_tracks => (
  is       => 'rw',
  isa      => 'ArrayRef[EGTrackHubs::TrackHubDB::Track]',
  default  => sub { [] },
);

# Rewrite parent subs
sub BUILD {
  my $self = shift;
  push @{ $self->_order }, 'superTrack';
};

sub _prepare_data {
  my $self = shift;
  my %data = $self->SUPER::_prepare_data;
  $data{ superTrack} = $self->show ? 'on show' : 'on';
  return %data;
}

# Special subs
sub add_sub_track {
  my $self = shift;
  my ($track) = @_;
  
  # Shallow copy of the track data
  my %subtrack_data = %$track;
  
  # Add the supertrack as parent (required by the subtrack)
  $subtrack_data{ parent } = $self->track;
  
  # Create the subtrack object
  my $subtrack = EGTrackHubs::TrackHubDB::SubTrack->new( %subtrack_data );
  
  push @{ $self->sub_tracks }, $subtrack;
  
  # Also, check that the super-track has the same type as the newly added subtrack
  my $sub_type   = $subtrack->type;
  my $super_type = $self->type;
  if (not defined $super_type) {
    $self->type( $sub_type );
  } elsif ($super_type ne $sub_type) {
    carp "WARNING: The supertrack has mixed types ($sub_type, $super_type)";
  }
  return 1;
}

sub to_string {
  my $self = shift;
  
  my @lines;
  
  # Print the supertrack-specific fields
  push @lines, $self->SUPER::to_string;
  
  # Add each subtrack
  for my $sub_track (@{ $self->sub_tracks }) {
    push @lines, $sub_track->to_string;
  }
  
  return join("\n", @lines);
}

__PACKAGE__->meta->make_immutable;
1;

