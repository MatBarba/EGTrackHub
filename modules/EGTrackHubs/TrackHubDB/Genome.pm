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

has hub_dir => (
  is     => 'rw',
  isa    => 'Str',
  writer => '_set_hub_dir',
  reader => '_get_hub_dir',
);

has genome_dir => (
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
  isa     => 'HashRef[EGTrackHubs::TrackHubDB::Track]',
);

sub hub_dir {
  my $self = shift;
  my ($dir) = @_;
  
  if (defined $dir) {
    $self->_set_hub_dir($dir);
    $self->update_genome_dir;
  }
  
  return $self->_get_hub_dir;
}

sub update_genome_dir {
  my ($self) = shift;
  die "Can't update genome dir if the hub dir is not defined" if not defined $self->_get_hub_dir;
  
  my $genome_dir = File::Spec->catfile(
    $self->_get_hub_dir,
    $self->id
  );
  $self->genome_dir($genome_dir);
}

sub config_text {
  my $self = shift;
  
  if (not defined $self->genome_dir) {
    croak "Can't create config text without a directory.";
  }
  my $trackdb_path = File::Spec->catfile(
    $self->genome_dir,
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
  
  if (not defined $self->genome_dir) {
    croak "Can't create genome file without a directory.";
  }
  
  mkdir $self->genome_dir;
  return 1;
}

sub add_track {
  my $self = shift;
  my ($track) = @_;
  $self->tracks->{$track->id} = $track;
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

