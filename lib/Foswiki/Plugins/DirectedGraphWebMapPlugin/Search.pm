# See bottom of file for default license and copyright information

=begin TML

---+ package DirectedGraphWebMapPlugin::Search



=cut

package Foswiki::Plugins::DirectedGraphWebMapPlugin::Search;

# Always use strict to enforce variable scoping
use strict;
use warnings;

require Foswiki::Func;    # The plugins API

sub populateWebMapArray {
    my ( $package, $web, $params ) = @_;
    my @topicList = Foswiki::Func::getTopicList($web);

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

    # $webmap{$baseTopic}{$targetTopic} = 1 if $baseTopic links to $targetTopic.
    # DOES NOT CROSS WEBS
    my %webmap;

    my %referencedIn;
    for my $targetTopic (@topicList) {
        next if exists $excludeTopic{$targetTopic};

        my $matches = Foswiki::Func::query(
            "\\b$targetTopic\\b",
            \@topicList,
            {
                web                 => $web,
                casesensitive       => 1,
                type                => 'regex',
                files_without_match => 1
            }
        );
        while ( $matches->hasNext ) {
            my $webtopic = $matches->next;
            my ( $unused_web, $baseTopic ) =
              Foswiki::Func::normalizeWebTopicName( '', $webtopic );

            next if exists $excludeTopic{$baseTopic};
            $webmap{$baseTopic}{$targetTopic} = 1;
        }

        #print STDERR "searched for $targetTopic";

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
