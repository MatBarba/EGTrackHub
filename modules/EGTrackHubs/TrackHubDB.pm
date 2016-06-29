package EGTrackHubs::TrackHubDB;

use strict;
use warnings;
use autodie;
use Carp;
$Carp::Verbose = 1;

use Moose;
use namespace::autoclean;
use File::Spec;
use File::Path qw(make_path);

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

has root_dir => (
  is     => 'rw',
  isa    => 'Str',
  writer => '_set_root_dir',
  reader => '_get_root_dir',
);

has hub_dir => (
  is     => 'rw',
  isa    => 'Str',
);

has genomes => (
  is      => 'rw',
  isa     => 'HashRef[EGTrackHubs::TrackHubDB::Genome]',
  default => sub { {} },
);

sub root_dir {
  my $self = shift;
  my ($dir) = @_;
  
  if (defined $dir) {
    $self->_set_root_dir($dir);
    $self->update_hub_dir;
  }
  
  return $self->_get_root_dir;
}

sub update_hub_dir {
  my ($self) = shift;
  die "Can't update hub dir if the root dir is not defined" if not defined $self->_get_root_dir;
  
  my $hub_dir = File::Spec->catfile(
    $self->_get_root_dir,
    $self->id
  );
  $self->hub_dir($hub_dir);
}

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
  $self->make_trackdb_files();
  return 1;
}

sub make_hub_file {
  my $self = shift;
  
  croak "Can't create hub file without a directory." if (not defined $self->hub_dir);
  my $hub_path = File::Spec->catfile($self->hub_dir, $self->hub_file);
  
  make_path $self->hub_dir;
  open my $hub_fh, '>', $hub_path;
  print $hub_fh $self->hub_file_content;
  close $hub_fh;
  return 1;
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
  
  if (not defined $self->hub_dir) {
    croak "Can't create genomes file without a directory.";
  } elsif (not keys %{ $self->genomes }) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my $genomes_path = File::Spec->catfile(
    $self->hub_dir,
    $self->genomes_file
  );
  
  open my $genomes_fh, '>', $genomes_path;
  print $genomes_fh $self->genomes_file_content;
  close $genomes_fh;
  return 1;
}

sub genomes_file_content {
  my $self = shift;
  
  if (not keys %{ $self->genomes }) {
    croak "Can't create genomes files without any genome assemblies";
  }
  my @lines;
  for my $genome_id (keys %{ $self->genomes }) {
    my $genome = $self->genomes->{ $genome_id };
    push @lines, $genome->config_text;
  }
  return join "\n\n", @lines;
}

sub make_genomes_dirs {
  my $self = shift;
  
  for my $genome_id (keys %{ $self->genomes }) {
    my $genome = $self->genomes->{ $genome_id };
    $genome->make_genome_dir;
  }
  return 1;
}

sub make_trackdb_files {
  my $self = shift;
  
  for my $genome_id (keys %{ $self->genomes }) {
    my $genome = $self->genomes->{ $genome_id };
    $genome->make_trackdb_file;
  }
  return 1;
}

sub add_genome {
  my $self = shift;
  my ($genome) = @_;
  
  if (defined $self->genomes->{ $genome->id }) {
    croak "The trackhub already has a genome named $genome->id";
  }
  my $genomes = $self->genomes->{ $genome->id } = $genome;
  $genomes->hub_dir($self->hub_dir);
  return 1;
}


__PACKAGE__->meta->make_immutable;
1;

