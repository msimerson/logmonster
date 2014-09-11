#!/usr/bin/perl

# by Matt Simerson & Phil Nadeau
# circa 2008, but based in installer in Mail::Toaster dating back to the 20th century

# v1.3 - 2012-10-23
#      - added apt-get support
#      - added app install support

use strict;
use warnings;

our $VERSION = 1.3;

use CPAN;
use English qw( -no_match_vars );

my $deps = {
    'modules' => [
        { module => 'Date::Format'      , info => { port => 'TimeDate' } },
        { module => 'Params::Validate'  , info => {} },
        { module => 'Mail::Send'        , info => { port => 'Mail::Tools' }  },
        { module => 'Regexp::Log'       , info => {} },
#       { module => 'Mail::Toaster'     , info => {} },
#       { module => 'Provision::Unix'   , info => {} },
    ],
    'apps' => [
#        { app => 'expat'         , info => { port => 'expat2',  dport=>'expat2' } },
#        { app => 'gettext'       , info => { port => 'gettext', dport=>'gettext'} },
#        { app => 'gmake'         , info => { port => 'gmake',   dport=>'gmake'  } },
    ]
};

$EUID == 0 or die "You will have better luck if you run me as root.\n";

# this causes problems when CPAN is not configured.
#$ENV{PERL_MM_USE_DEFAULT} = 1;       # supress CPAN prompts

$ENV{FTP_PASSIVE} = 1;        # for FTP behind NAT/firewalls

my @failed;
foreach ( @{ $deps->{apps} } ) {
    my $name = $_->{app} or die 'missing app name';
    install_app( $name, $_->{info} );
};

foreach ( @{ $deps->{modules} } ) {
    my $module = $_->{module} or die 'missing module name';
    my $info   = $_->{info};
    my $version = $info->{version} || '';
    print "checking for $module $version\n";

    eval "use $module $version";
    next if ! $EVAL_ERROR;
    next if $info->{ships_with} && $info->{ships_with} eq 'perl';

    install_module( $module, $info, $version );
    eval "use $module $version";
    if ($EVAL_ERROR) {
        push @failed, $module;
    }
}

if ( scalar @failed > 0 ) {
    print "The following modules failed installation:\n";
    print join( "\n", @failed );
    print "\n";
}

exit;

sub install_app {
    my ( $app, $info) = @_;

    if ( lc($OSNAME) eq 'darwin' ) {
        install_app_darwin($app, $info );
    }
    elsif ( lc($OSNAME) eq 'freebsd' ) {
        install_app_freebsd($app, $info );
    }
    elsif ( lc($OSNAME) eq 'linux' ) {
        install_app_linux( $app, $info );
    };

};

sub install_app_darwin {
    my ($app, $info ) = @_;

    my $port = $info->{dport} || $app;

    if ( ! -x '/opt/local/bin/port' ) {
        print "MacPorts is not installed! Consider installing it.\n";
        return;
    } 

    system "/opt/local/bin/port install $port" 
        and warn "install failed for Darwin port $port";
}

sub install_app_freebsd {
    my ($app, $info ) = @_;

    print " from ports...";
    my $name = $info->{port} || $app;

    if (`/usr/sbin/pkg_info | /usr/bin/grep $name`) {
        return print "$app is installed.\n";
    }

    print "installing $app";

    my ($portdir) = </usr/ports/*/$name>;

    if ( $portdir && -d $portdir && chdir $portdir ) {
        print " from ports ($portdir)\n";
        system "make install clean" 
            and warn "'make install clean' failed for port $app\n";
    }
}

sub install_app_linux {
    my ($app, $info ) = @_;

    if ( -x '/usr/bin/yum' ) {
        my $rpm = $info->{rpm} || $app;
        system "/usr/bin/yum -y install $rpm";
    }
    elsif ( -x '/usr/bin/apt-get' ) {
        system "/usr/bin/apt-get -y install $app";
    }
    else {
        warn "no Linux package manager detected\n";
    };
};


sub install_module {

    my ($module, $info, $version) = @_;

    if ( lc($OSNAME) eq 'darwin' ) {
        install_module_darwin($module, $info, $version);
    }
    elsif ( lc($OSNAME) eq 'freebsd' ) {
        install_module_freebsd($module, $info, $version);
    }
    elsif ( lc($OSNAME) eq 'linux' ) {
        install_module_linux( $module, $info, $version);
    };

    eval "require $module";
    return 1 if ! $EVAL_ERROR;

    install_module_cpan($module, $version);
};

sub install_module_cpan {

    my ($module, $version) = @_;

    print " from CPAN...";

    # some Linux distros break CPAN by auto/preconfiguring it with no URL mirrors.
    # this works around that annoying little habit
    no warnings;
    $CPAN::Config = get_cpan_config();
    use warnings;

    if ( $module eq 'Provision::Unix' && $version ) {
        $module =~ s/\:\:/\-/g;
        $module = "M/MS/MSIMERSON/$module-$version.tar.gz";
    }
    CPAN::Shell->install($module);
}

sub install_module_darwin {
    my ($module, $info, $version) = @_;

    my $dport = '/opt/local/bin/port';
    if ( ! -x $dport ) {
        print "MacPorts is not installed! Consider installing it.\n";
        return;
    } 

    my $port = "p5-$module";
    $port =~ s/::/-/g;
    system "$dport install $port" 
        and warn "install failed for Darwin port $module";
}

sub install_module_freebsd {
    my ($module, $info, $version) = @_;

    print " from ports...";
    my $name = $info->{port} || $module;
    my $portname = "p5-$name";
    $portname =~ s/::/-/g;

    if (`/usr/sbin/pkg_info | /usr/bin/grep $portname`) {
        return print "$module is installed.\n";
    }

    print "installing $module";

    my ($portdir) = </usr/ports/*/$portname>;

    if ( $portdir && -d $portdir && chdir $portdir ) {
        print " from ports ($portdir)\n";
        system "make install clean" 
            and warn "'make install clean' failed for port $module\n";
    }
}

sub install_module_linux {
    my ($module, $info, $version) = @_;

    if ( -x '/usr/bin/yum' ) {
        my $rpm = $info->{rpm} || $module;
        my $package = "perl-$rpm";
        $package =~ s/::/-/g;
        system "/usr/bin/yum -y install $package";
    }
    elsif ( -x '/usr/bin/apt-get' ) {
        my $lib = 'lib' . $module . '-perl';
        $lib =~ s/::/-/g;
        system "/usr/bin/apt-get -y install $lib";
    }
    else {
        warn "no Linux package manager detected\n";
    };
};

sub get_cpan_config {

    my $ftp = `which ftp`; chomp $ftp;
    my $gzip = `which gzip`; chomp $gzip;
    my $unzip = `which unzip`; chomp $unzip;
    my $tar  = `which tar`; chomp $tar;
    my $make = `which make`; chomp $make;
    my $wget = `which wget`; chomp $wget;

    return 
{
  'build_cache' => q[10],
  'build_dir' => qq[$ENV{HOME}/.cpan/build],
  'cache_metadata' => q[1],
  'cpan_home' => qq[$ENV{HOME}/.cpan],
  'ftp' => $ftp,
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[],
  'gzip' => $gzip,
  'histfile' => qq[$ENV{HOME}/.cpan/histfile],
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[5],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[1],
  'keep_source_where' => qq[$ENV{HOME}/.cpan/sources],
  'lynx' => q[],
  'make' => $make,
  'make_arg' => q[],
  'make_install_arg' => q[],
  'makepl_arg' => q[],
  'ncftp' => q[],
  'ncftpget' => q[],
  'no_proxy' => q[],
  'pager' => q[less],
  'prerequisites_policy' => q[follow],
  'scan_cache' => q[atstart],
  'shell' => q[/bin/csh],
  'tar' => $tar,
  'term_is_latin' => q[1],
  'unzip' => $unzip,
  'urllist' => [ 'http://www.perl.com/CPAN/', 'http://mirrors.kernel.org/pub/CPAN/', 'ftp://cpan.cs.utah.edu/pub/CPAN/', 'ftp://mirrors.kernel.org/pub/CPAN', 'ftp://osl.uoregon.edu/CPAN/', 'http://cpan.yahoo.com/', 'ftp://ftp.funet.fi/pub/languages/perl/CPAN/' ],
  'wget' => $wget, };
}


