# See bottom of file for default license and copyright information

=begin TML

---+ package DirectedGraphWebMapPlugin::FindRenderedLinks



=cut

package Foswiki::Plugins::DirectedGraphWebMapPlugin::FindRenderedLinks;

# Always use strict to enforce variable scoping
use strict;
use warnings;

require Foswiki::Func;    # The plugins API

sub populateWebMapArray {
    my ( $package, $web, $params ) = @_;
    my @topicList = Foswiki::Func::getTopicList($web);

    my %webmap;

    # $webmap{$baseTopic}{$targetTopic} = 1 if $baseTopic links to $targetTopic.
    # DOES NOT CROSS WEBS

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
        foreach (@Foswiki::Plugins::DirectedGraphWebMapPlugin::systemTopics) {
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
            $Foswiki::Plugins::DirectedGraphWebMapPlugin::debug
              && Foswiki::Func::writeDebug(
                __PACKAGE__ . " : Skipping $web.$baseTopic (excluded)" );
            next;
        }
        $Foswiki::Plugins::DirectedGraphWebMapPlugin::debug
          && Foswiki::Func::writeDebug(
            __PACKAGE__ . " : Scanning $web.$baseTopic" );

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
                $Foswiki::Plugins::DirectedGraphWebMapPlugin::debug
                  && Foswiki::Func::writeDebug(
"Skipping $baseTopic -> $targetTopic ($targetTopic excluded)"
                  );
                next;
            }
            $Foswiki::Plugins::DirectedGraphWebMapPlugin::debug
              && Foswiki::Func::writeDebug("$baseTopic -> $targetTopic");
            $webmap{$baseTopic}{$targetTopic} = 1;
        }
    }
    foreach my $topic (@topicList) {
        next if exists $excludeTopic{$topic};

        # ensure that every topic has an entry in the array
        # -- linking to itself (which we should ignore later)
        $webmap{$topic}{$topic} = 0;
    }

    return \%webmap;
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
