#!/usr/bin/perl -w

# Author          : Johan Vromans
# Created On      : Sat May 30 13:10:48 2015
# Last Modified By: Johan Vromans
# Last Modified On: Tue Mar 27 09:57:08 2018
# Update Count    : 267
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

# Package name.
my $my_package = 'MSProTools';
# Program name and version.
my ($my_name, $my_version) = qw( flatten 0.12 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dbname = "mobilesheets.db";
my $songid;
my $songsrc;
my $newpdf;
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use MobileSheetsPro::DB;
use MobileSheetsPro::Annotations::PDF;

db_open( $dbname, { NoVersionCheck => 1, RaiseError => 1, Trace => $trace } );

my $r;

if ( $songid ) {
    $r = [ [ $songid ] ];
}
else {
    $r = dbh->selectall_arrayref( "SELECT SongId FROM AnnotationsBase".
				  " ORDER BY Id" );
}

my %seen;

foreach ( @$r ) {

    $songid = $_->[0];
    next if $seen{$songid}++;

    unless ( $songsrc ) {
	my $r = dbh->selectall_arrayref( "SELECT Path from Files WHERE SongId = ?",
					 {}, $songid );
	if ( $r && $r->[0] ) {
	    $songsrc = $r->[0]->[0];
	    $songsrc =~ s;^.*/;;;
	}
    }

    unless ( $newpdf ) {
	$newpdf = $songsrc;
	$newpdf =~ s/\.([^.]+)$/_$1/;
	$newpdf .= ".pdf";
    }
    warn("Flattening [$songid] \"$songsrc\" into \"$newpdf\" ...\n");
    unless ( -s $songsrc ) {
	warn("No source for [$songid] \"$songsrc\"\n");
	undef $songsrc;
    }
    else {
	undef $songsrc unless $songsrc =~ /\.(pdf|jpe?g|png)$/i;
    }

    flatten_song( dbh, $songid, $songsrc, $newpdf );
    undef $songsrc;
    undef $newpdf;
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions('ident'	=> \$ident,
		   'db=s',	=> \$dbname,
		   'song=i'	=> \$songid,
		   'songsrc|songpdf=s'	=> \$songsrc,
		   'output=s'	=> \$newpdf,
		   'verbose'	=> \$verbose,
		   'trace'	=> \$trace,
		   'help|?'	=> \$help,
		   'man'	=> \$man,
		   'debug'	=> \$debug)
	  or $pod2usage->(2);
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
}

__END__

################ Documentation ################

=head1 NAME

flatten - process MSPro annotations

=head1 SYNOPSIS

flatten [options]

 Options:
   --song=NN		selects a single song by number
   --songsrc=XXX	explicitly specifies a source document
   --songpdf=XXX	explicitly specifies a source document
   --output=XXX		explicitly specifies the output PDF
   --db=XXX		the MSPro database (default mobilesheets.db)
   --ident		show identification
   --help		brief help message
   --man                full documentation
   --verbose		verbose information

=head1 OPTIONS

=over 8

=item B<--songid=>I<NN>

Selects a single song by its number. The number can be found by
unpacking the backup set in verbose mode (see msb_unpack).

If no songid is specified, all songs with annotations are processed.

=item B<--songsrc=>I<XXX>

Specifies the name of the source document, overriding the default.

Currently supported document types are PDF and JPG. Note that the
document type is determined by file name extension.

Use with B<--songid>.

=item B<--output=>I<XXX>

Specifies the name of the resultant PDF, overriding the default.

Default is the name of the source document, with the extension
appended to the name and C<".pdf"> added. For example, C<"My
Song.cho"> becomes C<"My Song_cho.pdf">.

Use with B<--songid>.

=item B<--db=>I<XXX>

Specifies an alternative name for the MobileSheetsPro database.
Default is C<"mobilesheets.db">.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

More verbose information.

=back

=head1 DESCRIPTION

PDF documents are created for each file that has annotations. For
PDF sources the original document is included, so the new PDF
document contains the original plus the annotations. For other
source files, the PDF document will contain empty pages containing
the annotations.

Currently supported annotations:

- drawing annotations (line, rectangle, circle, free)

- text annotations, but no fancy font stuff

=head1 DISCLAIMER

This is 'work in progress' and 'works for me'.

Much is based upon reverse engineering the MSPro database contents and
backup set format. Many bits and bytes are still not taken into
account.

THERE IS NO GUARANTEE THAT THIS PROGRAM WILL DO ANYTHING USEFUL FOR YOU.

=cut
