package EGTrackHubs::TrackHubDB;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
use namespace::autoclean;
use File::Spec;

use EGTrackHubs::TrackHubDB::Genome;

# Attributes
has id => (
  is     => 'ro',
  isa    => 'Str',
  required  => 1,
);

has short_label => (
  is     => 'ro',
  isa    => 'Str',
  required  => 1,
);

has long_label => (
  is     => 'ro',
  isa    => 'Str',
  required  => 1,
);

has email => (
  is     => 'ro',
  isa    => 'Str',
  required  => 1,
);

has description_url => (
  is     => 'ro',
  isa    => 'Str',
  required  => 1,
);

has hub_file => (
  is      => 'ro',
  isa     => 'Str',
  default => 'hub.txt'
);

has genomes_file => (
  is      => 'rw',
  isa     => 'Str',
  default => 'genomes.txt'
);

has dir => (
  is     => 'rw',
  isa    => 'Str',
);

has genomes => (
  is      => 'rw',
  isa     => 'HashRef[EGTrackHubs::TrackHubDB::Genome]',
  default => sub { {} },
);

sub create_files {
  my ($self, $dir) = @_;
  
  croak "Can't find root dir $dir" if not -d $dir;
  
  # Make trackhub dir
  $self->dir( "$dir/" . $self->id );
  mkdir $self->dir;
  
  # Generate files
  $self->make_hub_file();
  $self->make_genomes_file();
  $self->make_genomes_dirs();
}

sub make_hub_file {
  my $self = shift;
  
  croak "Can't create hub file without a directory." if (not defined $self->{dir});
  my $hub_path = File::Spec->catfile($self->{dir}, $self->{hub_file});
  
  open my $hub_fh, '>', $hub_path;
  print $hub_fh $self->hub_file_content;
  close $hub_fh;
}

sub hub_file_content {
  my $self = shift;
  
  my %content = (
    hub            => $self->id,
    shortLabel     => $self->short_label,
    longLabel      => $self->long_label,
    genomesFile    => $self->genomes_file,
    email          => $self->email,
    descriptionUrl => $self->description_url,
  );
  my @content_order = qw(
    hub
    shortLabel
    longLabel
    genomesFile
    email 
    descriptionUrl
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

sub make_genomes_file {
  my $self = shift;
  
}

sub make_genomes_dirs {
  my $self = shift;
  
}

sub add_genome {
  my $self = shift;
  my ($genome) = @_;
  
  if (defined $self->genomes->{ $genome->id }) {
    croak "The trackhub already has a genome named $genome->id";
  }
  my $genomes = $self->genomes->{ $genome->id } = $genome;
}


__PACKAGE__->meta->make_immutable;
1;

