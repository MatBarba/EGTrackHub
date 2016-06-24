package EGTrackHubs::TrackHubDB::TrackDB;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
use namespace::autoclean;

# Attributes
has id => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

has short_label => (
  is     => 'ro',
  isa    => 'Str',
);

has long_label => (
  is     => 'ro',
  isa    => 'Str',
);

has type => (
  is     => 'ro',
  isa    => 'Str',
);

use overload '""' => 'to_string';
            
sub to_string {
  my $self = shift;
  
  return $self->id;
}


__PACKAGE__->meta->make_immutable;
1;


