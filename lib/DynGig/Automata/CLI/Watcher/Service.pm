=head1 NAME

DynGig::Automata::CLI::Watcher::Service - CLI for watcher service.

=cut
package DynGig::Automata::CLI::Watcher::Service;

use warnings;
use strict;
use Carp;

use Cwd qw();
use File::Spec;
use File::Temp;
use Pod::Usage;
use Getopt::Long qw( :config bundling );

use DynGig::Util::CLI;
use DynGig::Util::Setuid;
use DynGig::Automata::MapReduce;

use constant { NICE => 19, PAUSE => 60 };

our %SERVICE = ( prefix => 'wmr' );

$| ++;

=head1 EXAMPLE

 use DynGig::Automata::CLI::Watcher::Service;

 DynGig::Automata::CLI::Watcher::Service->main
 (
     user => 'username',
     root => '/watcher/root/path',
     command => '/watcher/run/command/path', ## CLI of watcher run
     'log-size' => 100000,
     'log-keep' => 10,
 );

=head1 SYNOPSIS

$exe B<--help>

$exe name .. [B<--root> dir] [B<--user> user] [B<--command> path]
[B<--log-keep> number] [B<--log-size> number] B<--up>

$exe name .. [B<--root> dir] [B<--user> user] [B<--command> path]
[B<--log-keep> number] [B<--log-size> number] B<--restart>

$exe name .. [B<--root> dir] [B<--status>]

$exe name .. [B<--root> dir] B<--down>

$exe name .. [B<--root> dir] B<--kill>

=cut
sub main
{
    my ( $class, %option ) = @_;

    map { croak "$_ not defined" if ! defined $option{$_} }
        qw( command root user log-keep log-size );

    my $menu = DynGig::Util::CLI->new
    (
        'h|help','help menu',
        's|status','service status',
        'u|up','set up service',
        'd|down','down service, stop process gracefully',
        'k|kill','down and exit service, kill process',
        'r|restart','restart service gracefully',
        'log-size=i',"[ $option{'log-size'} ] size of each log",
        'log-keep=i',"[ $option{'log-keep'} ] number of logs to keep",
        'user=s',"[ $option{user} ] run as user",
        'root=s',"[ $option{root} ]",
        'command=s',"[ $option{command} ]",
    );
    
    my %pod_param = ( -input => __FILE__, -output => \*STDERR );
    my @argv = @ARGV;

    Pod::Usage::pod2usage( %pod_param )
        unless Getopt::Long::GetOptions( \%option, $menu->option() );

    if ( $option{h} )
    {
        warn join "\n", "Default value in [ ]", $menu->string(), "\n";
        return 0;
    }

    Pod::Usage::pod2usage( %pod_param ) unless @ARGV;

    if ( $> )
    {
        @ARGV = @argv;
        DynGig::Util::Setuid->sudo();
    }

    my $root = $option{root};

    croak "chdir $root: $!" unless chdir $root;

    my $service = File::Spec->join( File::Spec->rootdir(), 'service' );
    my $svc = Cwd::abs_path( 'service' );

    for my $dir ( $svc, $service )
    {
        croak 'invalid service directory' if ! $dir || -e $dir && ! -d $dir;
        croak "mkdir $dir: $!" unless -d $dir || mkdir $dir
    }

    my $prefix = length $SERVICE{prefix} ? $SERVICE{prefix}.'-' : '';

    $option{s} = ! grep { $option{$_} } qw( u d k r ) if ! $option{s};

    for my $name ( @ARGV )
    {
        my $watcher = $prefix.$name;
        my $link = File::Spec->join( $service, $watcher );
        my $svc = File::Spec->catdir( $svc, $watcher );
        my $log = File::Spec->catdir( $svc, 'log' );
## down/kill
        if ( $option{k} )
        {
            die "$name: kill failed\n" unless ( ! -l $link || unlink $link )
                && _svc( '-dx', $svc ) && _svc( '-dx', $log );
        }
        elsif ( $option{d} )
        {
            die "$name: down failed\n" unless _svc( '-d', $link );
        }
## restart
        if ( $option{r} )
        {
            $option{u} = 1;

            if ( -l $link )
            {
                die "$name: restart failed\n"
                    unless _svc( '-u', $link ) && _svc( '-t', $link );

                $option{u} = 0;
            }
        }
## up
        if ( $option{u} )
        {
            eval { DynGig::Automata::MapReduce->new( $name ) };

            if ( $@ )
            {
                warn "$name: $@\n" 
            }
            else
            {
                _start( $name, \%option, $link, $svc, $log );
            }
        }
## status
        system _path( 'svstat' ), $svc if $option{s};
    }

    return 0;
}

sub _path
{
    my $command = shift @_;

    return $command unless $SERVICE{path};

    my $path = Cwd::abs_path( $SERVICE{path} );

    return $path && -d $path ? File::Spec->join( $path, $command ) : $command;
}

sub _svc
{
    return ! system _path( 'svc' ), @_;
}

sub _start
{
    my ( $name, $o, $link, $svc, $log ) = @_;

    croak "cannot mkdir $log" if system 'mkdir', '-p', $log;

    my $setuidgid = _path( 'setuidgid' );
    my $multilog = _path( 'multilog' );
    my $user = $o->{user};
    my $main = './main';

    _run_script( $svc,
        "exec 2>&1\n%s %s nice -n %d %s %s --root %s --repeat || sleep %d",
        $setuidgid, $user, NICE, $o->{command}, $name, $o->{root}, PAUSE );

    _run_script( $log,
        "mkdir -p %s\nchown -R %s %s\nexec %s %s %s t I s%d n%d %s",
        $main, $user, $main, $setuidgid, $user, $multilog,
        $o->{'log-size'}, $o->{'log-keep'}, $main );

    die "$name: already running\n" if -l $link;

    croak "symlink: $!" unless symlink $svc, $link;
}

sub _run_script
{
    my $path = shift @_;
    my $handle = File::Temp->new();
    my $temp = $handle->filename();

    printf $handle "#!/bin/sh\n";
    printf $handle @_;

    $path = File::Spec->join( $path, 'run' );
    $handle->unlink_on_destroy( 0 );

    croak "rename $temp $path: $!" unless rename $temp, $path;
    croak "chmod $path: $!" unless chmod 0544, $path;
}

=head1 NOTE

See DynGig::Automata

=cut

1;

__END__
