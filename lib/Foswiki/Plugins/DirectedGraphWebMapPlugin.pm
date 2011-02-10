# See bottom of file for default license and copyright information

=begin TML

---+ package DirectedGraphWebMapPlugin

=cut

package Foswiki::Plugins::DirectedGraphWebMapPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Digest::MD5 qw( md5_hex );
use Storable qw( dclone freeze thaw );
use File::Find qw( find );

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.
# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '$Date: 2008-12-14 19:49:56 +0200 (Sun, 14 Dec 2008) $';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Creates directed graphs showing links between topics';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries set in =LocalSite.cfg=, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
our $NO_PREFS_IN_TOPIC = 1;

our @systemTopics = qw(WebAtom
  WebChanges
  WebHome
  WebIndex
  WebLeftBar
  WebNotify
  WebPreferences
  WebRss
  WebSearch
  WebSearchAdvanced
  WebStatistics
  WebTopicList
  WebCreateNewTopic);

our $debug;
my $pluginName = 'DirectedGraphWebMapPlugin';

# Guaranteed not to be a topic name:
my $nodeUrlOutput = '&!@';

# Cache webmaps so that multiple maps may be created from a single pass over all of the topics
# The caches for a web are cleared when any topic in the web is changed (or renamed)
my $webmaps;

my $processingDotMarkup;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} = 1;
    # Optional: See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See %SYSTEMWEB%.Plugins for help in adding your plugin
    # configuration to the =configure= interface.
    # my $setting = $Foswiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} || 0;

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesValue("DEBUG");

    # Register the _TOPICMAP function to handle %TOPICMAP{...}%
    # This will be called whenever %TOPICMAP% or %TOPICMAP{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'TOPICMAP', \&_TOPICMAP );

    # Register the _WEBMAP function to handle %WEBMAP{...}%
    # This will be called whenever %WEBMAP% or %WEBMAP{...}% is
    # seen in the topic text.
    Foswiki::Func::registerTagHandler( 'WEBMAP', \&_WEBMAP );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    #Foswiki::Func::registerRESTHandler('example', \&restExample);

    $processingDotMarkup = 0;

    # Plugin correctly initialized
    return 1;
}

sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic,
        $newAttachment ) = @_;

 # DirectedGraphPlugin saves attachments and updates attachment-related metadata
 # when it renders the dot graph produced by DirectedGraphWebMapPlugin.
 # That should not invalidate the cache.
    if ( not $processingDotMarkup ) {
        _cleanCache($oldWeb);

        _cleanCache($newWeb) if $newWeb ne $oldWeb;
    }
}

sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

 # DirectedGraphPlugin saves attachments and updates attachment-related metadata
 # when it renders the dot graph produced by DirectedGraphWebMapPlugin.
 # That should not invalidate the cache.
    if ( not $processingDotMarkup ) {
        _cleanCache($web);
    }
}

# The function used to handle the %TOPICMAP{...}% macro
# You would have one of these for each macro you want to process.
sub _TOPICMAP {
    my ( $session, $in_params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.
    my %params = %$in_params;

    my $t0;
    if ($debug) {
        require Time::HiRes;
        $t0 = [ Time::HiRes::gettimeofday() ];
    }

    commonParameterDefaults( \%params, $theWeb, $theTopic );

    if ( $params{"topic"} ) {

        # topic parameter is defined
    }
    elsif ( $params{"_DEFAULT"} ) {
        $params{"topic"} = $params{"_DEFAULT"};
    }
    else {
        $params{"topic"} = $theTopic;
    }
    unless ( Foswiki::Func::topicExists( $params{"web"}, $params{"topic"} ) ) {
        return
"\%RED\% !DirectedGraphWebMapPlugin error: Topic $params{web}.$params{topic} does not exist \%ENDCOLOR\%";
    }

 # links and backlinks are both permitted to be zero, hence the use of "defined"
    unless ( defined $params{"backlinks"} ) {
        if ( defined $params{"links"} ) {
            $params{"backlinks"} = $params{"links"};
        }
        else {
            $params{"backlinks"} =
              Foswiki::Func::getPluginPreferencesValue("BACKLINKS");
            unless ( defined $params{"backlinks"} ) {
                $params{"backlinks"} =
                  Foswiki::Func::getPluginPreferencesValue("LINKS");
                unless ( defined $params{"backlinks"} ) {
                    $params{"backlinks"} = 1;
                }
            }
        }
    }

    unless ( defined $params{"links"} ) {
        $params{"links"} = Foswiki::Func::getPluginPreferencesValue("LINKS");
        unless ( defined $params{"links"} ) {
            $params{"links"} = 2;
        }
    }

    if ($debug) {
        &Foswiki::Func::writeDebug( "$pluginName: \$params{$_} = "
              . ( defined( $params{$_} ) ? "\"$params{$_}\"" : "undef" ) )
          foreach ( sort keys %params );
    }

    my $graph;
    if ( $params{"cache"} ) {
        $graph = _readSavedGraph( \%params );
    }

    if ( not defined $graph ) {
        my $webmap = getWebMap( \%params );

        my @returnlist;

        my $dot_options = '';
        $dot_options .= "file=\"" . $params{"file"} . "\" "
          if defined $params{"file"};
        $dot_options .= "engine=\"" . $params{"engine"} . "\" "
          if defined $params{"engine"};
        push @returnlist, "<dot ${dot_options}map=1>";

        push @returnlist, "digraph webmap {";
        push @returnlist,
          "node [shape=Mrecord];";    # uses less space than an ellipse
        push @returnlist,
          "node [height=\"0.3\", fontsize=14];";   # makes the text fill the box
        push @returnlist, "size=\"" . $params{"size"} . "\";";
        push @returnlist, "rankdir=$params{rankdir};";
        my $webbgcolor =
          Foswiki::Func::getPreferencesValue( "WEBBGCOLOR", $params{"web"} );
        $webbgcolor = '#DDDDDD' unless defined $webbgcolor;
        my $fontcolor = "black";

        if ( $webbgcolor =~ /^#(..)(..)(..)$/ ) {
            my $red   = hex($1);
            my $green = hex($2);
            my $blue  = hex($3);

            # Use white if the color is dark
            $fontcolor = "white" if ( $red + $green + $blue ) < ( 3 * 76 );
        }
        push @returnlist,
          qq(node [style=filled, color="$webbgcolor", fontcolor="$fontcolor"];);

        # generate the "focus" node here,
        # and forwardlinks and backlinks only generate outer nodes.
        push @returnlist,
            qq("$params{topic}" [URL=")
          . Foswiki::Func::getViewUrl( $params{"web"}, $params{topic} )
          . qq("];);
        $webmap->{ $params{"topic"} }{$nodeUrlOutput} = 1;

        # forward links
        push @returnlist,
          forwardlinks( $params{"links"}, $params{"topic"}, $webmap,
            $params{'web'} );

        # back links
        push @returnlist,
          backlinks( $params{"backlinks"}, $params{"topic"}, $webmap,
            $params{'web'} );

        push @returnlist, "}";

        push @returnlist, "</dot>";

        $graph = join( "\n", @returnlist );
        _saveGraph( \%params, $graph ) if $params{"cache"};
    }

    if ($debug) {
        $graph =
          "<verbatim>\n$graph\n</verbatim>$graph\nDGWMP elapsed seconds: "
          . Time::HiRes::tv_interval($t0) . "<br>";
    }
    $processingDotMarkup = 1;
    if ($debug) {
        $t0 = [ Time::HiRes::gettimeofday() ];
    }
    $graph = Foswiki::Func::expandCommonVariables( $graph, $theTopic, $theWeb );
    if ($debug) {
        $graph .=
          "DGP elapsed seconds: " . Time::HiRes::tv_interval($t0) . "\n\n";
    }
    $processingDotMarkup = 0;

    return $graph;
}

# The function used to handle the %WEBMAP{...}% macro
sub _WEBMAP {
    my ( $session, $in_params, $theTopic, $theWeb ) = @_;

    # $session  - a reference to the Foswiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.
    #
    my %params = %$in_params;

    my $t0;
    if ($debug) {
        require Time::HiRes;
        $t0 = [ Time::HiRes::gettimeofday() ];
    }

    commonParameterDefaults( \%params, $theWeb, $theTopic );

    if ($debug) {
        &Foswiki::Func::writeDebug(
            "$pluginName: \$params{$_} = "
              . (
                defined(
                    $params{$_}
                    ? "'$params{$_}'"
                    : 'undef'
                )
              )
        ) foreach ( sort keys %params );
    }

    my $graph;
    if ( $params{"cache"} ) {
        $graph = _readSavedGraph( \%params );
    }

    if ( not defined $graph ) {
        my $webmap = getWebMap( \%params );

        my @returnlist;

        my $dot_options = '';
        $dot_options .= "file=\"" . $params{"file"} . "\" "
          if defined $params{"file"};
        $dot_options .= "engine=\"" . $params{"engine"} . "\" "
          if defined $params{"engine"};
        push @returnlist, "<dot ${dot_options}map=1>";

        push @returnlist, "digraph webmap {";
        push @returnlist,
          "node [shape=Mrecord];";    # uses less space than an ellipse
        push @returnlist,
          "node [height=\"0.3\", fontsize=14];";   # makes the text fill the box
        push @returnlist, "size=\"" . $params{"size"} . "\";";
        push @returnlist, "rankdir=$params{rankdir};";
        my $webbgcolor =
          Foswiki::Func::getPreferencesValue( "WEBBGCOLOR", $params{"web"} );
        $webbgcolor = '#DDDDDD' unless defined $webbgcolor;
        my $fontcolor = "black";

        if ( $webbgcolor =~ /^#(..)(..)(..)$/ ) {
            my $red   = hex($1);
            my $green = hex($2);
            my $blue  = hex($3);

            # Use white if the color is dark
            $fontcolor = "white" if ( $red + $green + $blue ) < ( 3 * 100 );
        }
        push @returnlist,
          qq(node [style=filled, color="$webbgcolor", fontcolor="$fontcolor"];);

        foreach my $baseTopic ( sort keys %$webmap ) {
            my $url = Foswiki::Func::getViewUrl( $params{'web'}, $baseTopic );
            push @returnlist, qq("$baseTopic" [URL="$url"];);
            foreach my $targetTopic ( sort keys %{ $webmap->{$baseTopic} } ) {
                push @returnlist, qq("$baseTopic" -> "$targetTopic";)
                  if ( $webmap->{$baseTopic}{$targetTopic} );
            }
        }

        push @returnlist, "}";

        push @returnlist, "</dot>";

        $graph = join( "\n", @returnlist );
        _saveGraph( \%params, $graph ) if $params{"cache"};
    }

    if ($debug) {
        $graph =
          "<verbatim>\n$graph\n</verbatim>$graph\nDGWMP elapsed seconds: "
          . Time::HiRes::tv_interval($t0) . "<br>";
    }
    $processingDotMarkup = 1;
    if ($debug) {
        $t0 = [ Time::HiRes::gettimeofday() ];
    }
    $graph = Foswiki::Func::expandCommonVariables( $graph, $theTopic, $theWeb );
    if ($debug) {
        $graph .=
          "DGP elapsed seconds: " . Time::HiRes::tv_interval($t0) . "\n\n";
    }
    $processingDotMarkup = 0;

    return $graph;
}

sub commonParameterDefaults {
    my ( $params, $theWeb, $theTopic ) = @_;
    unless ( $params->{"web"} and Foswiki::Func::webExists( $params->{"web"} ) )
    {
        $params->{"web"} = $theWeb;
    }

    unless ( $params->{"size"} ) {
        $params->{"size"} = Foswiki::Func::getPluginPreferencesValue("SIZE");
        unless ( $params->{"size"} ) {
            $params->{"size"} = "8.5,6.5";
        }
    }

    unless ( defined $params->{"cache"} ) {
        $params->{"cache"} = Foswiki::Func::getPluginPreferencesValue("CACHE");
        unless ( defined $params->{"cache"} ) {
            $params->{"cache"} = "on";
        }
    }
    $params->{"cache"} = Foswiki::Func::isTrue( $params->{"cache"} );

    unless ( $params->{"file"} and $params->{"file"} =~ /^\w+$/ ) {
        $params->{"file"} = undef;
    }

    unless ( $params->{"engine"} and $params->{"engine"} =~ /^\w+$/ ) {
        $params->{"engine"} = undef;
    }

    # Check if it is defined, so that the parameter may be empty
    # and still override the plugin preference.
    unless ( defined $params->{"expand"} ) {
        $params->{"expand"} =
          Foswiki::Func::getPluginPreferencesValue("EXPAND");
        unless ( $params->{"expand"} ) {
            $params->{"expand"} = "";
        }
    }

    unless ( $params->{"exclude"} ) {
        $params->{"exclude"} = "";
    }

    unless ( defined $params->{"excludesystem"} ) {
        $params->{"excludesystem"} = 0;
    }

    unless ( defined $params->{"rankdir"} ) {
        $params->{rankdir} = "LR" if ( $params->{"lr"} );
        $params->{rankdir} = "TB" unless $params->{rankdir};
    }

    if ( defined $params->{"mapper"}
        and $params->{"mapper"} =~ /([a-zA-Z0-9_:]+)/ )
    {
        $params->{"mapper"} = $1;
    }
    else {
        $params->{mapper} = "FindRenderedLinks";

        #$params->{mapper} = "Search";
    }
}

sub forwardlinks {
    my $links     = shift;
    my $baseTopic = shift;
    my $webmap    = shift;
    my $web       = shift;
    my @returnlist;

    if ($links) {
        $links--;
        my $baseTopicUrl = Foswiki::Func::getViewUrl( $web, $baseTopic );
        foreach my $targetTopic ( sort keys %{ $webmap->{$baseTopic} } ) {
            next if $targetTopic eq $nodeUrlOutput;
            if ( $webmap->{$baseTopic}{$targetTopic} ) {
                $webmap->{$baseTopic}{$targetTopic} = 0;
                0
                  && $debug
                  && Foswiki::Func::writeDebug("$baseTopic -> $targetTopic");
                my $targetTopicUrl =
                  Foswiki::Func::getViewUrl( $web, $targetTopic );
                if ( not $webmap->{$targetTopic}{$nodeUrlOutput} ) {
                    push @returnlist,
                      qq("$targetTopic" [URL="$targetTopicUrl"];);
                    $webmap->{$targetTopic}{$nodeUrlOutput} = 1;
                }
                push @returnlist, qq("$baseTopic" -> "$targetTopic";);
                push @returnlist, forwardlinks( $links, $targetTopic, $webmap );
            }
        }
    }
    return @returnlist;
}

sub backlinks {
    my $links       = shift;
    my $targetTopic = shift;
    my $webmap      = shift;
    my $web         = shift;
    my @returnlist;

    if ($links) {
        $links--;
        my $targetTopicUrl = Foswiki::Func::getViewUrl( $web, $targetTopic );
        foreach my $baseTopic ( sort keys %$webmap ) {
            next if $baseTopic eq $nodeUrlOutput;
            if ( $webmap->{$baseTopic}{$targetTopic} ) {
                $webmap->{$baseTopic}{$targetTopic} = 0;
                0
                  && $debug
                  && Foswiki::Func::writeDebug("$baseTopic -> $targetTopic");
                my $baseTopicUrl =
                  Foswiki::Func::getViewUrl( $web, $baseTopic );
                if ( not $webmap->{$baseTopic}{$nodeUrlOutput} ) {
                    push @returnlist, qq("$baseTopic" [URL="$baseTopicUrl"];);
                    $webmap->{$baseTopic}{$nodeUrlOutput} = 1;
                }
                push @returnlist, qq("$baseTopic" -> "$targetTopic";);
                push @returnlist, backlinks( $links, $baseTopic, $webmap );
            }
        }
    }
    return @returnlist;
}

sub getWebMap {
    my $params = shift;
    my $web    = $params->{"web"};

    # Fetch web from cache
    my $mapkey =
        $params->{"mapper"}
      . $params->{"expand"}
      . $params->{"excludesystem"}
      . $params->{"exclude"};
    if ( not exists $webmaps->{$web}->{$mapkey} and $params->{"cache"} ) {
        $webmaps->{$web}->{$mapkey} = _readSavedMap( $web, $mapkey );
    }
    if ( not defined $webmaps->{$web}->{$mapkey} or not $params->{"cache"} ) {
        my $mapper =
          "Foswiki::Plugins::DirectedGraphWebMapPlugin::" . $params->{"mapper"};
        eval "use $mapper;";
        die $@ if $@;
        $webmaps->{$web}->{$mapkey} =
          $mapper->populateWebMapArray( $web, $params );

        _saveMap( $web, $mapkey, $webmaps->{$web}->{$mapkey} )
          if $params->{"cache"};
    }

    # Make a deep copy of the webmap so that forwardlinks() and
    # backlinks() don't break the cache copy
    return dclone( $webmaps->{$web}->{$mapkey} );
}

sub _readSavedMap {
    my $web    = shift;
    my $mapkey = shift;

    my $IN_FILE;

    #print STDERR "Looking for map: " . _mapFilename( $web, $mapkey ) . "\n";
    open( $IN_FILE, '<', _mapFilename( $web, $mapkey ) ) or return undef;

    #print STDERR "Reading map from " . _mapFilename( $web, $mapkey ) . "\n";
    binmode $IN_FILE;
    local $/ = undef;    # set to read to EOF
    my $data = <$IN_FILE>;
    close($IN_FILE);

    unless ( eval { $data = thaw($data); 1; } ) {
        $data = undef;
    }
    return $data;
}

sub _saveMap {
    my $web    = shift;
    my $mapkey = shift;
    my $map    = shift;

    # Don't care if this fails, because the cause might be
    # another process writing to the same file
    my $FILE;
    if ( open( $FILE, '>', _mapFilename( $web, $mapkey ) ) ) {
        binmode $FILE;
        print $FILE freeze($map);
        close($FILE);
    }

    #print STDERR "Saved map to " . _mapFilename( $web, $mapkey ) . "\n";
}

sub _mapFilename {
    my $web    = shift;
    my $mapkey = shift;

    $web = Foswiki::Sandbox::validateWebName($web) || 'x';
    $web =~ s{[\\/.]}{!}g;
    return Foswiki::Sandbox::untaintUnchecked(
            Foswiki::Func::getWorkArea('DirectedGraphWebMapPlugin') 
          . "/$web."
          . md5_hex($mapkey) );
}

sub _readSavedGraph {
    my $params = shift;

    my $IN_FILE;

    #print STDERR "Looking for graph " . _graphFilename($params) . "\n";
    open( $IN_FILE, '<', _graphFilename($params) ) or return undef;

    #print STDERR "Reading graph from " . _graphFilename($params) . "\n";
    binmode $IN_FILE;
    local $/ = undef;    # set to read to EOF
    my $data = <$IN_FILE>;
    close($IN_FILE);

    unless ( eval { $data = ${ thaw($data) }; 1; } ) {
        $data = undef;
    }
    return $data;
}

sub _saveGraph {
    my $params = shift;
    my $graph  = shift;

    # Don't care if this fails, because the cause might be
    # another process writing to the same file
    my $FILE;
    if ( open( $FILE, '>', _graphFilename($params) ) ) {
        binmode $FILE;
        print $FILE freeze( \$graph );
        close($FILE);
    }

    #print STDERR "Saved graph to " . _graphFilename($params) . "\n";
}

sub _graphFilename {
    my $params = shift;

    my $graphkey = join(
        ',',
        map {
            "$_=>"
              . ( defined( $params->{$_} ) ? "'$params->{$_}'" : "undef" )
          } sort keys %$params
    );

    my $web = Foswiki::Sandbox::validateWebName( $params->{web} ) || 'x';
    $web =~ s{[\\/.]}{!}g;
    return Foswiki::Sandbox::untaintUnchecked(
            Foswiki::Func::getWorkArea('DirectedGraphWebMapPlugin') 
          . "/$web."
          . md5_hex($graphkey) );
}

sub _cleanCache {
    my $web = shift;
    delete $webmaps->{$web};
    $web =~ s{[\\/]}{!}g;

    find(
        {
            untaint         => 1,
            untaint_pattern => qr|^([-+@\w./:]+)$|,
            wanted          => sub {

            # unchecked untaint is fine because the directory came from the core
            # and all files in that directory belong to this plugin
                unlink($1) if /^($web\..*)/;
            },
        },
        Foswiki::Func::getWorkArea('DirectedGraphWebMapPlugin')
    );
}

1;
__END__
This copyright information applies to the DirectedGraphWebMapPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# DirectedGraphWebMapPlugin is Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of the Foswiki distribution.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. 
#
# This license applies to DirectedGraphWebMapPlugin *and also to any derivatives*
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
