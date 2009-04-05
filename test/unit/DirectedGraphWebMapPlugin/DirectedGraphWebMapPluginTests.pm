use strict;

package DirectedGraphWebMapPluginTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::Func;
use Foswiki::Attrs;
use Foswiki::Plugins::DirectedGraphWebMapPlugin;
use CGI;

my %basic_web_links;
my %basic_TopicTwo_links;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{target_web} = "$this->{test_web}Target";
    Foswiki::Func::createWeb( $this->{target_web} );

    my %topic_text = (
        "TopicOne" => "TopicTwo, [[Topic Three]], "
          . "\%SEARCH{\"Four\" scope=\"topic\" nonoise=\"on\" format=\"\$topic\"}\%",
        "TopicTwo"          => "TopicThree $this->{test_web}.TopicFive",
        "TopicThree"        => "TopicThatDoesNotExist",
        "TopicFour"         => "$this->{target_web}.TopicOne",
        "TopicFive"         => "TopicSix WebHome",
        "TopicSix"          => "TopicSeven",
        "TopicSeven"        => "TopicOne \%INCLUDE{TopicEight}\%",
        "TopicEight"        => "TopicNine",
        "TopicNine"         => "TopicEight",
        "WebAtom"           => "",
        "WebChanges"        => "",
        "WebHome"           => "",
        "WebIndex"          => "",
        "WebLeftBar"        => "",
        "WebNotify"         => "",
        "WebPreferences"    => "",
        "WebRss"            => "",
        "WebSearch"         => "",
        "WebSearchAdvanced" => "",
        "WebStatistics"     => "",
        "WebTopicList"      => "",
    );
    for my $topic ( keys %topic_text ) {
        $this->writeTopic( $this->{test_web}, $topic, $topic_text{$topic} );
    }

    my %alternate_text = (
        "AlternateOne" => "AlternateTwo AlternateThree",
        "AlternateTwo" => "AlternateOne"
    );
    for my $topic ( keys %alternate_text ) {
        $this->writeTopic( $this->{target_web}, $topic,
            $alternate_text{$topic} );
    }

    %basic_web_links = (
        TopicOne            => [ 'TopicTwo',   'TopicThree' ],
        TopicTwo            => [ 'TopicThree', 'TopicFive' ],
        TopicThree          => undef,
        TopicFour           => undef,
        TopicFive           => [ 'TopicSix',   'WebHome' ],
        TopicSix            => ['TopicSeven'],
        TopicSeven          => ['TopicOne'],
        TopicEight          => ['TopicNine'],
        TopicNine           => ['TopicEight'],
        WebAtom             => undef,
        WebChanges          => undef,
        WebHome             => undef,
        WebIndex            => undef,
        WebLeftBar          => undef,
        WebNotify           => undef,
        WebPreferences      => undef,
        WebRss              => undef,
        WebSearch           => undef,
        WebSearchAdvanced   => undef,
        WebStatistics       => undef,
        WebTopicList        => undef,
        $this->{test_topic} => undef,
    );

    %basic_TopicTwo_links = (
        TopicOne   => ["TopicTwo"],
        TopicTwo   => [ 'TopicThree', 'TopicFive' ],
        TopicThree => undef,
        TopicFive  => [ 'TopicSix', 'WebHome' ],
        TopicSix   => undef,
        WebHome    => undef,
    );

}

sub tear_down {
    my $this = shift;
    $this->removeWeb( $this->{target_web} );
    $this->SUPER::tear_down();
}

sub writeTopic {
    my ( $this, $web, $topic, $text ) = @_;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save();
}

sub mapTest {
    my $this    = shift;
    my $output  = shift;
    my $options = shift;

    # The defaults
    $options->{size}    = '8.5,6.5'         if not defined $options->{size};
    $options->{rankdir} = 'TB'              if not defined $options->{rankdir};
    $options->{web}     = $this->{test_web} if not defined $options->{web};
    $options->{shape}   = "Mrecord"         if not defined $options->{shape};
    $options->{fontsize} = 14    if not defined $options->{fontsize};
    $options->{height}   = "0.3" if not defined $options->{height};

    my $WEBBGCOLOR =
      Foswiki::Func::getPreferencesValue( "WEBBGCOLOR", $options->{web} );
    $WEBBGCOLOR = '#DDDDDD' if not defined $WEBBGCOLOR;

    # output should be wrapped in <dot> ... </dot>
    $this->assert( scalar( $output =~ s/^<dot(.*?)>\s*//o ), $output );
    my $dot_attrs = $1;
    $this->assert( scalar( $output =~ s/<\/dot>\s*$//so ), $output );

    if ( exists $options->{engine} ) {
        $this->assert( scalar( $dot_attrs =~ s/^\s*engine="([^"]*)"\s*//o ),
            "<dot> parameters: $dot_attrs" );
        $this->assert_str_equals( $1, $options->{engine}, $1 );
    }
    if ( exists $options->{file} ) {
        $this->assert( scalar( $dot_attrs =~ s/^\s*file="([^"]*)"\s*//o ),
            "<dot> parameters: $dot_attrs" );
        $this->assert_str_equals( $1, $options->{file}, $1 );
    }
    $this->assert(
        scalar( $dot_attrs =~ s/map=1\s*//o ),
        "<dot> parameters: $dot_attrs"
    );

    # There should only be (at most) whitespace left in the dot attributes
    $this->assert_does_not_match( qr/\S/, $dot_attrs,
        "<dot> parameters: $dot_attrs" );

    # graph should be wrapped in digraph G { ... }
    $this->assert( scalar( $output =~ s/^digraph\s+\w+\s+{\s*//o ), $output );
    $this->assert( scalar( $output =~ s/}\s*$//so ), $output );

    $this->assert( scalar( $output =~ s/^node\s*\[shape=(.+?)\];\s*//o ),
        $output );
    $this->assert_str_equals( $1, $options->{shape}, $1 );

    $this->assert(
        scalar(
            $output =~ s/^node\s*\[height="(.+?)", fontsize=(.+?)\];\s*//o
        ),
        $output
    );
    $this->assert_str_equals( $1, $options->{height},   $1 );
    $this->assert_str_equals( $2, $options->{fontsize}, $2 );

    $this->assert( scalar( $output =~ s/^size="([^"]*)";\s*//o ), $output );
    $this->assert_str_equals( $1, $options->{size}, $1 );

    $this->assert( scalar( $output =~ s/^rankdir=([^;]*);\s*//o ), $output );
    $this->assert_str_equals( $1, $options->{rankdir}, $1 );

    $this->assert(
        scalar(
            $output =~
s/^node \[style=filled, color="([^"]*)", fontcolor="([^"]*)"\];\s*//o
        ),
        $output
    );
    $this->assert_str_equals( $1, $WEBBGCOLOR );
    $this->assert( $2 eq 'black' or $2 eq 'white' );

    foreach my $topic ( keys %{ $options->{links} } ) {
        $this->assert(
            scalar( $output =~ s/"$topic"\s*\[URL="([^"]*)"\];\s*// ),
            "$topic: $output" );
        $this->assert_str_equals( $1,
            Foswiki::Func::getViewUrl( $options->{web}, $topic ), $1 );

        next unless defined $options->{links}->{$topic};

        foreach my $destination ( @{ $options->{links}->{$topic} } ) {
            $this->assert(
                scalar( $output =~ s/"$topic"\s*->\s*"$destination";\s*// ),
                "$topic->$destination: $output" );
        }
    }

    # There should only be (at most) whitespace left in the output
    $this->assert_does_not_match( qr/\S/, $output, $output );
}

sub test_basicWebMap {
    my $this = shift;

    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP(
        $this->{session},    new Foswiki::Attrs(""),
        $this->{test_topic}, $this->{test_web}
    );

    my %options = ( links => {%basic_web_links} );

    $this->mapTest( $output, \%options );
}

sub test_webMapWithSearch {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(expand="SEARCH")),
        $this->{test_topic}, $this->{test_web} );

    my %options = ( links => {%basic_web_links} );
    push @{ $options{links}->{TopicOne} }, 'TopicFour';

    $this->mapTest( $output, \%options );
}

sub test_webMapWithInclude {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(expand="INCLUDE")),
        $this->{test_topic}, $this->{test_web} );

    my %options = ( links => {%basic_web_links} );
    push @{ $options{links}->{TopicSeven} }, 'TopicNine';

    $this->mapTest( $output, \%options );
}

sub test_webMapWithExcludeSystem {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(excludesystem="1")),
        $this->{test_topic}, $this->{test_web} );

    my %options = ( links => {%basic_web_links} );
    for my $systemTopic ( grep { /^Web[A-Z]/ } keys %{ $options{links} } ) {
        delete $options{links}->{$systemTopic};
    }
    $options{links}->{TopicFive} = ['TopicSix'];    # No WebHome

    $this->mapTest( $output, \%options );
}

sub test_webMapWithExcludeAndExcludeSystem {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(exclude="TopicThree" excludesystem="1")),
        $this->{test_topic}, $this->{test_web} );

    my %options = ( links => {%basic_web_links} );
    delete $options{links}->{TopicThree};
    for my $targetlist ( values %{ $options{links} } ) {
        $targetlist = [ grep { $_ ne 'TopicThree' } @$targetlist ];
    }
    for my $systemTopic ( grep { /^Web[A-Z]/ } keys %{ $options{links} } ) {
        delete $options{links}->{$systemTopic};
    }
    $options{links}->{TopicFive} = ['TopicSix'];    # No WebHome

    $this->mapTest( $output, \%options );
}

sub test_webMapWithExclude {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(exclude="TopicThree")),
        $this->{test_topic}, $this->{test_web} );

    my %options = ( links => {%basic_web_links} );
    delete $options{links}->{TopicThree};
    for my $targetlist ( values %{ $options{links} } ) {
        $targetlist = [ grep { $_ ne 'TopicThree' } @$targetlist ];
    }

    $this->mapTest( $output, \%options );
}

sub test_webMapWithEngine {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(engine="neato")),
        $this->{test_topic}, $this->{test_web} );

    my %options = (
        links  => {%basic_web_links},
        engine => 'neato'
    );

    $this->mapTest( $output, \%options );
}

sub test_webMapWithFile {
    my $this = shift;

    $this->writeTopic( $this->{test_web}, $this->{test_topic}, "" );
    $this->writeTopic( $this->{test_web}, "WebPreferences",    "" );

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(file="myfile")),
        $this->{test_topic}, $this->{test_web} );

    my %options = (
        links => {%basic_web_links},
        file  => 'myfile'
    );

    $this->mapTest( $output, \%options );
}

sub test_webMapWithSize {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(size="10,10")),
        $this->{test_topic}, $this->{test_web} );

    my %options = (
        links => {%basic_web_links},
        size  => '10,10'
    );

    $this->mapTest( $output, \%options );
}

sub test_prefsWebMap {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_SIZE',
        "10,11" );
    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_EXPAND',
        "SEARCH,INCLUDE" );
    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP(
        $this->{session},    new Foswiki::Attrs(""),
        $this->{test_topic}, $this->{test_web}
    );

    my %options = (
        links => {%basic_web_links},
        size  => "10,11"
    );
    push @{ $options{links}->{TopicOne} },   'TopicFour';    # SEARCH
    push @{ $options{links}->{TopicSeven} }, 'TopicNine';    #INCLUDE

    DirectedGraphWebMapPluginTests::mapTest( $this, $output, \%options );
}

sub test_webMapWithWeb {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(web="$this->{target_web}")),
        $this->{test_topic}, $this->{test_web} );

    my %options = (
        links => {
            AlternateOne   => ["AlternateTwo"],
            AlternateTwo   => ["AlternateOne"],
            WebPreferences => undef
        },
        web => $this->{target_web}
    );

    $this->mapTest( $output, \%options );
}

sub test_webMapWithLr {
    my $this = shift;

    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP(
        $this->{session},    new Foswiki::Attrs(qq(lr="1")),
        $this->{test_topic}, $this->{test_web}
    );

    my %options = (
        links   => {%basic_web_links},
        rankdir => "LR",
    );

    $this->mapTest( $output, \%options );
}

sub test_webMapWithRankdir {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_WEBMAP( $this->{session},
        new Foswiki::Attrs(qq(rankdir="BT")),
        $this->{test_topic}, $this->{test_web} );

    my %options = (
        links   => {%basic_web_links},
        rankdir => "BT",
    );

    $this->mapTest( $output, \%options );
}

sub test_basicTopicMap {
    my $this = shift;

    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session}, new Foswiki::Attrs(""),
        "TopicTwo",       $this->{test_web}
    );

    my %options = ( links => {%basic_TopicTwo_links} );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithExcludeSystem {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(excludesystem="1")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    delete $options{links}->{WebHome};
    $options{links}->{TopicFive} = ['TopicSix'];    # Remove WebHome

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithExclude {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(exclude="topicThree")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    delete $options{link}->{TopicThree};
    $options{link}->{TopicTwo} = ['TopicFive'];

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithEngine {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(engine="neato")),
        "TopicTwo", $this->{test_web} );

    my %options = (
        links  => {%basic_TopicTwo_links},
        engine => 'neato'
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithFile {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(file="myfile")),
        "TopicTwo", $this->{test_web} );

    my %options = (
        links => {%basic_TopicTwo_links},
        file  => 'myfile'
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithSize {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(size="10,10")),
        "TopicTwo", $this->{test_web} );

    my %options = (
        links => {%basic_TopicTwo_links},
        size  => '10,10'
    );

    $this->mapTest( $output, \%options );
}

sub test_sizePrefsTopicMap {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_SIZE',
        "10,11" );
    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session}, new Foswiki::Attrs(""),
        "TopicTwo",       $this->{test_web}
    );

    my %options = (
        links => {%basic_TopicTwo_links},
        size  => "10,11"
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithWeb {
    my $this = shift;

    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session},
        new Foswiki::Attrs(qq(web="$this->{target_web}" topic="AlternateOne")),
        "TopicTwo",
        $this->{test_web}
    );

    my %options = (
        links => {
            AlternateOne => ['AlternateTwo'],
            AlternateTwo => ['AlternateOne'],
        },
        web => $this->{target_web}
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithLr {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(lr="1")),
        "TopicTwo", $this->{test_web} );

    my %options = (
        links   => {%basic_TopicTwo_links},
        rankdir => 'LR'
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithRankdir {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(rankdir="RL")),
        "TopicTwo", $this->{test_web} );

    my %options = (
        links   => {%basic_TopicTwo_links},
        rankdir => 'RL'
    );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithPrefsLinks1 {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_LINKS',
        "1" );
    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session}, new Foswiki::Attrs(qq()),
        "TopicTwo",       $this->{test_web}
    );

    my %options = ( links => {%basic_TopicTwo_links}, );
    $options{links}->{TopicFive} = undef;
    delete $options{links}->{TopicSix};
    delete $options{links}->{WebHome};

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithLinks1 {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(links="1")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links}, );
    $options{links}->{TopicFive} = undef;
    delete $options{links}->{TopicSix};
    delete $options{links}->{WebHome};

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithLinks1OverridesPrefs {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_LINKS',
        "0" );
    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(links="1")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links}, );
    $options{links}->{TopicFive} = undef;
    delete $options{links}->{TopicSix};
    delete $options{links}->{WebHome};

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithLinks0 {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(links="0")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => { TopicTwo => undef }, );

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithPrefsBackLinks3 {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_BACKLINKS',
        "3" );
    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session}, new Foswiki::Attrs(qq()),
        "TopicTwo",       $this->{test_web}
    );

    my %options = ( links => {%basic_TopicTwo_links} );
    $options{links}->{TopicSeven} = ['TopicOne'];
    $options{links}->{TopicSix}   = ['TopicSeven'];

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithBackLinks3 {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(backlinks="3")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    $options{links}->{TopicSeven} = ['TopicOne'];
    $options{links}->{TopicSix}   = ['TopicSeven'];

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithBackLinks3OverridesPrefs1 {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_BACKLINKS',
        "0" );
    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(backlinks="3")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    $options{links}->{TopicSeven} = ['TopicOne'];
    $options{links}->{TopicSix}   = ['TopicSeven'];

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithBackLinks3OverridesPrefs2 {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_BACKLINKS',
        "0" );
    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_LINKS',
        "1" );
    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(backlinks="3")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    $options{links}->{TopicSeven} = ['TopicOne'];
    $options{links}->{TopicSix}   = ['TopicSeven'];
    $options{links}->{TopicFive}  = undef;
    delete $options{links}->{WebHome};

    $this->mapTest( $output, \%options );
}

sub test_topicMap_WithBackLinks0 {
    my $this = shift;

    my $output =
      Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP( $this->{session},
        new Foswiki::Attrs(qq(backlinks="0")),
        "TopicTwo", $this->{test_web} );

    my %options = ( links => {%basic_TopicTwo_links} );
    delete $options{links}->{TopicOne};

    $this->mapTest( $output, \%options );
}

sub test_topicMapWithBackLinksPrefsOverridesLinksPrefs {
    my $this = shift;

    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_BACKLINKS',
        "3" );
    Foswiki::Func::setPreferencesValue( 'DIRECTEDGRAPHWEBMAPPLUGIN_LINKS',
        "1" );
    my $output = Foswiki::Plugins::DirectedGraphWebMapPlugin::_TOPICMAP(
        $this->{session}, new Foswiki::Attrs(qq()),
        "TopicTwo",       $this->{test_web}
    );

    my %options = ( links => {%basic_TopicTwo_links} );
    $options{links}->{TopicSeven} = ['TopicOne'];
    $options{links}->{TopicSix}   = ['TopicSeven'];
    $options{links}->{TopicFive}  = undef;
    delete $options{links}->{WebHome};

    $this->mapTest( $output, \%options );
}

1;
