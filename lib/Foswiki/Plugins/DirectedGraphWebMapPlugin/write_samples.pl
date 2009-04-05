#!/usr/bin/perl

# This program updates the sample images in the plugin topic,
# and - the hard part - their image maps
#
# Change $foswiki_base below to suit your environment

use strict;
use warnings;
use Cwd;
use File::Copy;

my $cwd = cwd();

my $foswiki_base = "/var/www/fwrel/core";

my $main_web_sample_topic = "DirectedGraphWebMapPluginMainWebSample";
open M, ">$foswiki_base/data/Sandbox/$main_web_sample_topic.txt " or die $!;
print M "\%WEBMAP{web=\"Main\" expand=\"INCLUDE\" size=\"15,15\"}\%\n";
close M or die $!;

chdir "$foswiki_base/bin";
my $main_text = `./view -topic Sandbox/$main_web_sample_topic -skin plain`;
my $main_png =
  "$foswiki_base/pub/Sandbox/$main_web_sample_topic/DirectedGraphPlugin_1.png";
my $main_map = $main_png;
$main_map =~ s/\.png$/.cmapx/;

die "$main_text\n$main_png does not exist" unless -e $main_png;
die "$main_text\n$main_map does not exist" unless -e $main_map;

my $topic_text = `./view -topic System/DirectedGraphWebMapPlugin -skin plain`;
my $topic_png =
"$foswiki_base/pub/System/DirectedGraphWebMapPlugin/DirectedGraphPlugin_1.png";
my $topic_map = $topic_png;
$topic_map =~ s/\.png$/.cmapx/;

die "$topic_text\n$topic_png does not exist" unless -e $topic_png;
die "$topic_text\n$topic_map does not exist" unless -e $topic_map;

copy( $main_png,
    "$cwd/../../../../pub/System/DirectedGraphWebMapPlugin/SampleMainWebMap.png"
) or die $!;
open M, $main_map or die $!;
my $main_map_content = '';
while (<M>) {
    $main_map_content .= $_;
}
close M or die $!;
$main_map_content =~ s/.*<map.*?>(.+)<\/map.*/$1/s or die;
$main_map_content =~
  s/http:\/\/.*?\/view.*?\/Main/%SCRIPTURLPATH{"view"}%\/%MAINWEB%/sg
  or die;
$main_map_content =~ s/\n/ /g;

copy( $topic_png,
    "$cwd/../../../../pub/System/DirectedGraphWebMapPlugin/sample.png" )
  or die $!;
open M, $topic_map or die $!;
my $topic_map_content = '';
while (<M>) {
    $topic_map_content .= $_;
}
close M or die $!;
$topic_map_content =~ s/.*<map.*?>(.+)<\/map.*/$1/s or die;
$topic_map_content =~
  s/http:\/\/.*?\/view.*?\/System/%SCRIPTURLPATH{"view"}%\/%SYSTEMWEB%/sg
  or die;
$topic_map_content =~ s/\n/ /g;

my $topic = "$cwd/../../../../data/System/DirectedGraphWebMapPlugin.txt";
-e $topic or die;
my $backup;
{
    my $n = 1;
    do {
        $backup = "$topic.$n.bak";
        $n++;
    } while ( -e $backup );
}
copy( $topic, $backup ) or die $!;

open M, $backup or die $!;
$topic_text = '';
while (<M>) {
    $topic_text .= $_;
}
close M or die $!;

$topic_text =~ s/(\%META:TOPICINFO{author=")\w+"/$1ProjectContributor"/ or die;
$topic_text =~ s/(user=")\w+"/$1ProjectContributor"/g or die;
$topic_text =~
s/(<map id="SampleMainWebMap" name="SampleMainWebMap">).*?(<\/map>)/$1$main_map_content$2/s
  or die;
$topic_text =~
  s/(<map id="sample" name="sample">).*?(<\/map>)/$1$topic_map_content$2/s
  or die;

open M, ">$topic" or die $!;
print M $topic_text;
close M or die;

END {
    chdir $cwd if $cwd;
}
