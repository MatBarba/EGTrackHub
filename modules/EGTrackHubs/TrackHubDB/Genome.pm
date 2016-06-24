package EGTrackHubs::TrackHubDB::Genome;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
use namespace::autoclean;

use EGTrackHubs::TrackHubDB::TrackDB;

# Attributes
has id => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

has dir => (
  is     => 'rw',
  isa    => 'Str',
);

has trackdb_file => (
  is      => 'rw',
  isa     => 'Str',
  default => 'trackDb.txt',
);

has trackdbs => (
  is      => 'rw',
  isa     => 'HashRef[EGTrackHubs::TrackHubDB::TrackDB]',
);

sub make_genome_dir {
  my $self = shift;
  mkdir $self->{dir};
}

sub add_trackdb {
  my $self = shift;
  my ($trackdb) = @_;
  $self->trackdbs->{$trackdb->id} = $trackdb;
}

sub make_trackdb_files {
  my $self = shift;
  
  # Init file
  my $trackdb_file = $self->{dir} . '/' . $self->{trackdb_file};
  open(my $trackdb_fh, '>', $trackdb_file);
  
  # Add each track inside
  foreach my $track (@{ $self->{trackdbs} }) {
    print $trackdb_fh $track;
  }
  
  close $trackdb_fh;
}


__PACKAGE__->meta->make_immutable;
1;

