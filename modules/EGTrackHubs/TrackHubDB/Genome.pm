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
  default => 'trackdb.txt',
);

has trackdbs => (
  is      => 'rw',
  isa     => 'HashRef[EGTrackHubs::TrackHubDB::TrackDB]',
);

sub config_text {
  my $self = shift;
  
  if (not defined $self->dir) {
    croak "Can't create config text without a directory.";
  }
  my $trackdb_path = File::Spec->catfile(
    $self->dir, 
    $self->trackdb_file
  );
  
  my %content = (
    genome  => $self->id,
    trackDb => $trackdb_path,
  );
  my @content_order = qw(
    genome
    trackDb
  );
  
  my @lines;
  my %missing_keys;
  for my $key (@content_order) {
    if (defined $content{$key}) {
      push @lines, "$key $content{$key}";
    } else {
      $missing_keys{$key}++;
    }
  }
  
  if (%missing_keys) {
    croak "Missing keys: " . join(', ', sort keys %missing_keys);
  }
  
  return join("\n", @lines) . "\n";
}

sub make_dir {
  my $self = shift;
  
  if (not defined $self->dir) {
    croak "Can't create hub file without a directory.";
  }
  
  my $dir_path = File::Spec->catfile(
    $self->{dir}, $self->{id}
  );
  mkdir $dir_path;
  return 1;
}

sub add_trackdb {
  my $self = shift;
  my ($trackdb) = @_;
  $self->trackdbs->{$trackdb->id} = $trackdb;
  return 1;
}

sub make_trackdb_file {
  my $self = shift;
  
  # Init file
  my $trackdb_file = $self->dir . '/' . $self->trackdb_file;
  open(my $trackdb_fh, '>', $trackdb_file);
  
  # Add each track inside
  foreach my $track (@{ $self->trackdbs }) {
    print $trackdb_fh $track;
  }
  
  close $trackdb_fh;
}


__PACKAGE__->meta->make_immutable;
1;

