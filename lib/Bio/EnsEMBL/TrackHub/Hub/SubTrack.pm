package Bio::EnsEMBL::TrackHub::Hub::SubTrack;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
extends 'Bio::EnsEMBL::TrackHub::Hub::Track';
use namespace::autoclean;

###############################################################################
# ATTRIBUTES
# This is just a track with a SuperTrack as a parent
has parent => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

###############################################################################
# BUILD METHODS
# Add "parent" to the list of parameters
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

__END__

=head1 DESCRIPTION

Object representing a track hub SubTrack.

A SuperTrack is simply a track with a SuperTrack as parent.

=head1 ATTRIBUTES

Same as a Track, except:

=over

=item I<parent> (string) is added

=back

=head1 USAGE

A Track is automatically converted to a SubTrack if it is added to a SuperTrack.
In that case, the SubTrack parent is automatically set.

There is therefor no reason to create a SubTrack manually.

=cut

