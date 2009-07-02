# See bottom of file for default license and copyright information

=begin TML

---+ package DirectedGraphWebMapPlugin



=cut

package Foswiki::Plugins::DirectedGraphWebMapPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

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
#our $NO_PREFS_IN_TOPIC = 1;

my @systemTopics = qw(WebAtom
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

my $debug;
my $pluginName = 'DirectedGraphWebMapPlugin';

# Guaranteed not to be a topic name:
my $nodeUrlOutput = '&!@';

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

    # Plugin correctly initialized
    return 1;
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

    my $webmap = getWebMap( \%params );

    my @returnlist;

    my $dot_options = '';
    $dot_options .= "file=\"" . $params{"file"} . "\" "
      if defined $params{"file"};
    $dot_options .= "engine=\"" . $params{"engine"} . "\" "
      if defined $params{"engine"};
    push @returnlist, "<dot ${dot_options}map=1>";

    push @returnlist, "digraph webmap {";
    push @returnlist, "node [shape=Mrecord];"; # uses less space than an ellipse
    push @returnlist,
      "node [height=\"0.3\", fontsize=14];";    # makes the text fill the box
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
    push @returnlist, qq("$params{topic}" [URL=")
      . Foswiki::Func::getViewUrl( $params{"web"}, $params{topic} ) . qq("];);
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

    if ($debug) {
        return ( "<verbatim>\n" . join( "\n", @returnlist ) . "\n</verbatim>" );
    }
    else {
        return Foswiki::Func::expandCommonVariables( ( join "\n", @returnlist ),
            $theTopic, $theWeb );
    }
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

    my $webmap = getWebMap( \%params );

    my @returnlist;

    my $dot_options = '';
    $dot_options .= "file=\"" . $params{"file"} . "\" "
      if defined $params{"file"};
    $dot_options .= "engine=\"" . $params{"engine"} . "\" "
      if defined $params{"engine"};
    push @returnlist, "<dot ${dot_options}map=1>";

    push @returnlist, "digraph webmap {";
    push @returnlist, "node [shape=Mrecord];"; # uses less space than an ellipse
    push @returnlist,
      "node [height=\"0.3\", fontsize=14];";    # makes the text fill the box
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

    if ($debug) {
        return ( "<verbatim>\n" . join( "\n", @returnlist ) . "\n</verbatim>" );
    }
    else {
        return Foswiki::Func::expandCommonVariables( ( join "\n", @returnlist ),
            $theTopic, $theWeb );
    }
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

    unless ( $params->{"file"} and $params->{"file"} =~ /^\w+$/ ) {
        $params->{"file"} = undef;
    }

    unless ( $params->{"engine"} and $params->{"engine"} =~ /^\w+$/ ) {
        $params->{"engine"} = undef;
    }

# Check if it is defined, so that the parameter may be empty and still override the plugin preference.
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
                $debug
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
                $debug
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

    my $webmap;

    # No caching
    $webmap = populateWebMapArray( $params->{"web"}, $params );

    ## Fetch web from cache
#my $mapkey = $params->{"expand"}.$params->{"excludesystem"}.$params->{"exclude"}.$params->{"web"};
#if (not exists $webmaps->{$mapkey})
#{
#    $webmaps->{$mapkey} = populateWebMapArray($params->{"web"}, $params);
#}
    ## Make a deep copy of the webmap so that forwardlinks() and backlinks() don't break the cache copy
    #my %webmapcopy;
    #for my $baseTopic (keys %{$webmaps->{$mapkey}})
    #{
    #    my %targets = %{$webmaps->{$mapkey}->{$baseTopic}};
    #    $webmapcopy{$baseTopic} = \%targets;
    #}
    #$webmap = \%webmapcopy;

    return $webmap;
}

sub populateWebMapArray {
    my $web       = $_[0];
    my $params    = $_[1];
    my @topicList = Foswiki::Func::getTopicList($web);

    my %webmap
      ; # $webmap{$baseTopic}{$targetTopic} = 1 if $baseTopic links to $targetTopic.  DOES NOT CROSS WEBS

    # Build a regex that matches a link to a topic in the same web
    my $urlhost = Foswiki::Func::getUrlHost();
    my $viewurl = Foswiki::Func::getViewUrl( $web, "TOPIC" );
    $viewurl =~ s/^$urlhost//;
    $viewurl =~ s:/TOPIC$::;
    my $href =
      qr(<a[^>]+href\s*=\s*"(?:$urlhost)?$viewurl/(\w+)(?:#\w+)?"[^>]*>);

    # Create a list of variables to be expanded prior to searching for links
    my $varList = $params->{"expand"};
    $varList =~ s/^\s+//;
    $varList =~ s/\s+$//;
    my @vars = split( /[ ,]+/, $varList );

    # Create a list of topics to be excluded
    my %excludeTopic = ();
    if ( $params->{"excludesystem"} ) {
        foreach (@systemTopics) {
            $excludeTopic{$_} = 1;
        }
    }
    my $excludeList = $params->{"exclude"};
    $excludeList =~ s/^\s+//;
    $excludeList =~ s/\s+$//;
    foreach ( split( /[ ,]+/, $excludeList ) ) {
        $excludeTopic{$_} = 1;
    }

    foreach my $baseTopic (@topicList) {
        if ( exists $excludeTopic{$baseTopic} ) {
            $debug
              && Foswiki::Func::writeDebug(
                "${pluginName}: Skipping $web.$baseTopic (excluded)");
            next;
        }
        $debug
          && Foswiki::Func::writeDebug(
            "${pluginName}: Scanning $web.$baseTopic");

        my $baseTopicText =
          Foswiki::Func::readTopicText( $web, $baseTopic, "", 1 );

        # expand WEB and TOPIC variables
        $baseTopicText =~
s/(%(?:HOME|NOTIFY|WEBPREFS|WIKIPREFS|WIKIUSERS)?TOPIC%)/Foswiki::Func::expandCommonVariables($1, $baseTopic, $web)/ge;
        $baseTopicText =~ s/%MAINWEB%/$Foswiki::cfg{UsersWebName}/ge
          ;    # faster than expandCommonVariables
        $baseTopicText =~ s/%SYSTEMWEB%/$Foswiki::cfg{SystemWebName}/ge;

        # skip meta
        $baseTopicText =~ s/%META[^%]+%//g;

        #         # throw away text part of forced links
        #         $baseTopicText =~ s/\[\[([^\]]*)(\]\[)?([^\]]*)\]\]/$1/g;
        # Throw away %WEBMAP% to prevent recursive rendering
        $baseTopicText =~ s/%WEBMAP%//g;
        $baseTopicText =~ s/%WEBMAP{[^}]*}%//g;

        # Throw away %TOPICMAP% to prevent recursive rendering
        $baseTopicText =~ s/%TOPICMAP%//g;
        $baseTopicText =~ s/%TOPICMAP{[^}]*}%//g;

        # expand user-specified variables
        for my $var (@vars) {
            $baseTopicText =~
s/(%$var%)/Foswiki::Func::expandCommonVariables($1, $baseTopic, $web)/ge;
            $baseTopicText =~
s/(%$var\{.*?}%)/Foswiki::Func::expandCommonVariables($1, $baseTopic, $web)/ge;
        }

        # ... in fact, throw away ALL remaining variables
        $baseTopicText =~ s/%\w+[^%]*%//g
          ; # The \w+ makes it more robust with respect to errors like $RED%. Note that [^%] matches a newline.
            # Discarding variables can also discard links if there are markup errors like the following:
            # %RED$ SomeLink %ENDCOLOR%

        my $renderedTopic =
          Foswiki::Func::renderText( $baseTopicText, $web, $baseTopic );
        my @links = $renderedTopic =~ /$href/g;
        while (@links) {
            my $targetTopic = shift @links;
            if ( exists $excludeTopic{$targetTopic} ) {
                $debug
                  && Foswiki::Func::writeDebug(
"Skipping $baseTopic -> $targetTopic ($targetTopic excluded)"
                  );
                next;
            }
            $debug && Foswiki::Func::writeDebug("$baseTopic -> $targetTopic");
            $webmap{$baseTopic}{$targetTopic} = 1;
        }
    }
    foreach my $topic (@topicList) {
        next if exists $excludeTopic{$topic};

# ensure that every topic has an entry in the array -- linking to itself (which we should ignore later)
        $webmap{$topic}{$topic} = 0;
    }

    return \%webmap;
}
1;
__END__
This copyright information applies to the DirectedGraphWebMapPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# DirectedGraphWebMapPlugin is Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
# Additional copyrights apply to some or all of the code as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
