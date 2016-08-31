package Bio::EnsEMBL::TrackHub::Hub::SuperTrack;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
extends 'Bio::EnsEMBL::TrackHub::Hub::Track';
use Bio::EnsEMBL::TrackHub::Hub::SubTrack;
use namespace::autoclean;

###############################################################################
# ATTRIBUTES
# As defined in https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html and
# https://genome.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html
# 
# NB: the visibility attribute is replaced by show in the SuperTrack object.
# Since it is a SuperTrack, it does not need a file/type of file by default
has '+visibility' => ( default => undef, );
has '+bigDataUrl' => ( required => 0 );
has '+type'       => ( required => 0 );

has show => (
  is      => 'rw',
  isa     => 'Bool',
  default => 1,
);

has sub_tracks => (
  is      => 'rw',
  isa     => 'ArrayRef[Bio::EnsEMBL::TrackHub::Hub::Track]',
  default => sub { [] },
);

###############################################################################
# BUILD METHODS
# Add "superTrack" to the list of parameters
# This parameter actually uses the show attribute
sub BUILD {
  my $self = shift;
  push @{ $self->_order }, 'superTrack';
}

sub _prepare_data {
  my $self = shift;
  my %data = $self->SUPER::_prepare_data;
  $data{superTrack} = $self->show ? 'on show' : 'on';
  return %data;
}

###############################################################################
# INSTANCE METHODS

# INSTANCE METHOD
# Purpose   : append a track as a subtrack of this supertrack
# Parameters: a Track object
sub add_sub_track {
  my $self = shift;
  my ($track) = @_;

  # Shallow copy of the track data
  my %subtrack_data = %$track;

  # Add the supertrack as parent (required by the subtrack)
  $subtrack_data{parent} = $self->track;

  # Create the subtrack object
  my $subtrack = Bio::EnsEMBL::TrackHub::Hub::SubTrack->new(%subtrack_data);

  push @{ $self->sub_tracks }, $subtrack;

  # Also, check that the super-track has the same type as the newly added subtrack
  my $sub_type   = $subtrack->type;
  my $super_type = $self->type;
  if ( not defined $super_type ) {
    $self->type($sub_type);
  }
  elsif ( $super_type ne $sub_type ) {
    carp "WARNING: The supertrack has mixed types ($sub_type, $super_type)";
  }
  return 1;
}

# INSTANCE METHOD
# Purpose   : returns the track text (for the file trackdb.txt) as a string
# Parameters: none
sub to_string {
  my $self = shift;

  my @lines;

  # Print the supertrack-specific fields
  push @lines, $self->SUPER::to_string;

  # Add each subtrack
  for my $sub_track ( @{ $self->sub_tracks } ) {
    push @lines, $sub_track->to_string;
  }

  return join( "\n", @lines );
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

Object representing a track hub SuperTrack.

A SuperTrack is simply a Track that contains a list of SubTracks, so that they
can be set all together.

=head1 ATTRIBUTES

Same as a Track, except:

=over

=item I<visibility> is removed


=item a I<show> attribute is added

This attribute is used by the supertrack parameter and can be set to
1 (show all) or 0 (hide all, default).

=item I<bigDataUrl> is removed

=item I<type> is not mandatory

But it can be used to give the type of the whole subset of tracks.

=back

=head1 METHODS

=head2 new

Same as Track, except for the changes of attributes above.

Usage:

 my $super_track = Bio::EnsEMBL::TrackHub::Hub::SuperTrack->new(
    track      => 'Supertrack',
    shortLabel => 'Signal density',
    type       => 'bigWig',
    show       => 1,
  );

=head2 to_string

Get the string of the track which can be used in the trackdb.txt file. This
also includes the list of all the subtracks.

=cut

