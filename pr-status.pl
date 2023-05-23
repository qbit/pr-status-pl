#!/usr/bin/perl

# vim: set ts=4 sw=4 tw=0:
# vim: set expandtab:

use strict;
use warnings;
use v5.32;
use Data::Dumper;

use Git;
use JSON qw( from_json );
use Mojolicious::Lite -signatures;
use Time::HiRes qw( time );

my $VERSION = 'v0.0.1';

my $repo_dir = "/var/lib/pr-status/nixpkgs";

$ENV{"GIT_CONFIG_SYSTEM"} = "";        # Ignore insteadOf rules
$ENV{"HOME"}              = "/tmp";    # Ignore ~/.netrc

Git::command_noisy( 'clone', 'https://github.com/nixos/nixpkgs', $repo_dir )
  if !-e $repo_dir;
my $repo = Git->repository( Directory => $repo_dir );

my $lock = 0;

sub get_commit {
    my $pr = shift;
    $repo->command( 'fetch', 'origin', "pull/${pr}/head:pr-status-${pr}" );
    $repo->command( 'checkout', "pr-status-$pr" );
    my $commit = $repo->command( 'rev-parse', 'HEAD' );
    $repo->command( 'checkout', 'master' );

    chomp $commit;

    return $commit;
}

sub check_nixpkg_branches {
    my $commit = shift;
    my $list   = [];

    return $list if $commit eq "";

    my $branches = $repo->command( 'branch', '-r', '--contains', $commit );

    foreach my $b ( split( '\n', $branches ) ) {
        $b =~ s/^\s+origin\///g;
        push( @$list, $b )
          if $b =~ m/^nixos|^nixpkgs|^staging|^master|^release/;
    }

    return $list;
}

sub figure_status {
    my $list   = shift;
    my $status = {
        state => "complete",
        info  => {},
    };
    my $release = "stable";

    my @unstable = qw/
      master
      staging
      staging-next
      nixpkgs-unstable
      nixos-unstable-small
      nixos-unstable
      /;
    my @stable = (
        'staging-\d\d\.\d\d',     'staging-next-\d\d\.\d\d',
        'nixos-\d\d\.\d\d-small', 'nixos-\d\d\.\d\d',
        'release-\d\d\.\d\d'
    );

    if ( grep /^master$/, @{$list} ) {
        $release = "unstable";
        foreach my $s (@unstable) {
            $status->{info}->{$s} = JSON::false;
            $status->{info}->{$s} = JSON::true if grep /^$s$/, @{$list};
        }
    }
    else {
        $release = "stable";
        foreach my $s (@stable) {

# handle this stuff with a regex so we don't have to specify "22.11" kinda stuff
            my @b  = grep /$s/, @{$list};
            my $ns = $b[0];
            if ( defined $ns ) {
                $status->{info}->{$ns} = JSON::false;
                $status->{info}->{$ns} = JSON::true if grep /^$s$/, @{$list};
            }
        }
    }

    foreach my $s ( keys %{ $status->{info} } ) {
        if ( $status->{info}->{$s} == JSON::false ) {
            $status->{state} = "open";
            last;
        }
    }

    return ( $release, $status );
}

get '/gc' => sub ($c) {
    my $start = time;
    $repo->command('gc');
    my $end = time;
    $c->render(
        json => {
            updateTime => sprintf( "%2f", $end - $start ),
            action     => 'gc'
        }
    );
};

get '/update' => sub ($c) {
    my $start = time;
    $repo->command('fetch');
    my $end = time;
    $c->render(
        json => {
            updateTime => sprintf( "%2f", $end - $start ),
            action     => 'update'
        }
    );
};

get '/' => sub ($c) {
    $c->render( text => 'hi' );
};

get '/:pr' => sub ($c) {
    my $pr = $c->param('pr');

    return unless $pr =~ m/^\d+$/;

    my $commit = get_commit($pr);

    my $start = time;
    my $list  = check_nixpkg_branches $commit;
    my $end   = time;

    my ( $release, $status ) = figure_status($list);

    my $result = {
        branches     => $list,
        pull_request => $pr,
        status       => $status->{state},
        release      => $release,
        status_info  => $status->{info},
        queryTime    => sprintf( "%2f", $end - $start )
    };

    $c->render( json => $result );
};

app->start;
