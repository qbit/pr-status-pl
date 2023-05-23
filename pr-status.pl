#!/usr/bin/perl

# vim: set ts=4 sw=4 tw=0:
# vim: set expandtab:

use strict;
use warnings;
use v5.32;

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
        push( @$list, $b ) if $b =~ m/nixos|nixpkgs|staging|master/;
    }

    return $list;
}

sub figure_status {
    my $list    = shift;
    my $release = shift;
    my $status  = {
        state => "complete",
        info  => {}
    };

    my @unstable =
      qw/ nixos-unstable nixos-unstable-small nixpkgs-unstable staging staging-next /;
    my @stable = qw/ release-22.11 nixos-22.11-small nixos-22.11 /;
    my @other  = qw / master /;

    if ( $release eq "stable" ) {
        foreach my $s (@stable) {
            $status->{info}->{$s} = grep /$s/, @{$list};
        }
    }
    if ( $release eq "unstable" ) {
        foreach my $s (@unstable) {
            $status->{info}->{$s} = grep /^$s$/, @{$list};
        }
    }

    foreach my $b ( keys %{ $status->{info} } ) {
        if ( !$status->{info}->{$b} ) {
            $status->{state} = "open";
            last;
        }
    }

    return $status;
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

get '/:release/:pr' => sub ($c) {
    my $pr      = $c->param('pr');
    my $release = $c->param('release');

    return unless $pr =~ m/^\d+$/;

    my $commit = get_commit($pr);

    my $start = time;
    my $list  = check_nixpkg_branches $commit;
    my $end   = time;

    my $status = figure_status( $list, $release );

    my $result = {
        branches     => $list,
        pull_request => $pr,
        status       => $status->{state},
        status_info  => $status->{info},
        queryTime    => sprintf( "%2f", $end - $start )
    };

    $c->render( json => $result );
};

app->start;
