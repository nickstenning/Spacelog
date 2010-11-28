#!/usr/bin/env perl
# $Id$

use strict;
use warnings;

use IO::File;
use Data::Dumper;
use JSON;
use Getopt::Long;

my $help;
my @lines;
my $glossary;

if (   !GetOptions( 'help|h' => \$help, )
    || $help
    || !@ARGV )
{
    print "Usage: markup.pl [dir/file]
                      --help : This help
eg:
   tools/markup.pl missions/ma6/transcripts/TEC

markup will attenmpt to automatically markup glossary references
in a processed TEC transcript. If given a file it will read from
the file and look for a _meta in the same directory. If given a
directory it will look for a TEC and _meta files in that directory.

";
    exit;
}

warn
"Will create broken marked up links for entries containing <sub>, and will add glossary links to already marked up text";
foreach my $dir (@ARGV) {
    process($dir);
}
exit;

sub load_meta {
    my ($file) = @_;
    my $fh = new IO::File;
    $fh->open( '<' . $file ) || die "Unable to load $file: $!";

    my $json_text;
    $fh->read( $json_text, -s $fh );
    $fh->close;

    my $json = JSON->new->allow_nonref;
    my $meta = $json->decode($json_text);
    $glossary = $meta->{glossary};
}

sub load_transcript {
    my ($file) = @_;
    my $fh = new IO::File;
    $fh->open( '<' . $file ) || die "Unable to load $file: $!";
    my $entry;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\[(-?\d\d:\d\d:\d\d:\d\d)\]/ ) {
            if ( $entry->{timestamp} ) {
                push( @lines, $entry );
                $entry = undef;
            }
            $entry->{timestamp} = $1;
        }
        elsif ( $line =~ /(^_\w+)\s*:\s*(.*)/ ) {
            $entry->{$1} = $2;
        }
        elsif ( $line =~ /^([A-Z-?\d*]+): (.*)/ ) {

            # Expand multiple speaker:text entries to separate logs lines
            if ( $entry->{speaker} ) {
                my %copy = %{$entry};
                push( @lines, $entry );
                $entry = \%copy;
            }
            $entry->{speaker} = $1;
            $entry->{text}    = $2;
        }
        elsif ( $line =~ /^(\s+\S.*)/ ) {
            $entry->{text} .= "\n$1";
        }
        elsif ( $line =~ /./ ) {
            chomp $line;
            warn "Unable to parse: '$line'";
        }
    }
    push( @lines, $entry );
    $fh->close;
}

sub markup_glossary {
    my $regex = join '|', map { s{(.)}{$1(?:<[^>]+>)?}g; $_ } keys %{$glossary};
    map { $_->{text} =~ s/\b($regex)\b/[glossary:$1 $1]/g; $_ } @lines;
}

sub process {
    my ($path) = @_;

    my $meta_file;
    my $transcript_file;
    if ( -d $path ) {
        $transcript_file = "$path/TEC";
        $meta_file       = "$path/_meta";
    }
    else {
        $transcript_file = $path;
        $meta_file       = $path;
        $meta_file =~ s:[^/]*$:_meta:;
    }
    load_transcript($transcript_file);
    load_meta($meta_file);
    markup_glossary() if keys %{$glossary};
    save_transcript("$transcript_file-markedup");
}

sub save_transcript {
    my ($file) = @_;
    my $fh = new IO::File;
    $fh->open( '>' . $file ) || die "Unable to save $file: $!";
    print "Saving $file\n";
    my $timestamp = '';
    foreach my $line (@lines) {
        if ( $line->{timestamp} ne $timestamp )  # Collapse duplicate timestamps
        {
            print $fh "[$line->{timestamp}]\n";
            foreach my $key ( sort grep( /^_/, keys %{$line} ) ) {
                print $fh "$key : $line->{$key}\n";
            }
        }
        print $fh "$line->{speaker}: $line->{text}\n\n";
        $timestamp = $line->{timestamp};

    }
    $fh->close;
}