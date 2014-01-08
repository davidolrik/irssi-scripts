#!/usr/bin/env perl

use strict;
use warnings;

use vars qw($VERSION %IRSSI %config);

use Irssi;

use DateTime;
use Mojo::UserAgent;
use Unicode::String qw[utf8 latin1];

$VERSION = '0.01';
%IRSSI = (
    authors         =>      'David Jack Wange Olrik',
    contact         =>      'djo@cpan.org',
    name            =>      'poshover_notify',
    description     =>      'Sends out push notifications to your mobile devices from Irssi via Pushover.net',
    license         =>      'Artistic',
    url             =>      'http://david.olrik.dk/',
);

sub cmd_pushover_notify ($$$) {
    Irssi::print('%G>>%n Prowl notify can be configured using settings:');
    Irssi::print('%G>>%n pushover_notify_token        : Your Pushover.net application token');
    Irssi::print('%G>>%n pushover_notify_userkey      : Your Pushover.net user key');
    Irssi::print('%G>>%n pushover_notify_show_privmsg : Notify about private messages.');
    Irssi::print('%G>>%n pushover_notify_show_hilight : Notify when your name is hilighted.');
    Irssi::print('%G>>%n pushover_notify_show_notify  : Notify when someone on your away list joins or leaves.');
}

sub cmd_pushover_notify_test ($$$) {
    notify("Test","This is a test",0);
}

sub notify {
    my ($event,$text,$priority) = @_;
    $priority = 0 unless defined($priority);

    # Don't send push notifications when unconfigured
    return unless Irssi::settings_get_str('pushover_notify_token');
    return unless Irssi::settings_get_str('pushover_notify_userkey');

    # Don't send push notifications when a proxy client is connected
    return if $config{proxy_client_count};

    my $params = {
        token     => Irssi::settings_get_str('pushover_notify_token'),
        user      => Irssi::settings_get_str('pushover_notify_userkey'),
        title     => join(' ', 'Irssi', $event),
        message   => $text,
        priority  => $priority, # [-2..2],
        timestamp => time(),
        sound     => 'pushover',
    };
    my $url = 'https://api.pushover.net/1/messages.json';

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post($url => form => $params);
    if (my $res = $tx->success) {
        # NOP
    }
    else {
        my ($err, $code) = $tx->error;
        my $error_message = $code ? "$code response: $err" : "Connection error: $err";
        Irssi::print("\%RError in pushover_notify:\%n $error_message");
    }
}

sub sig_message_private ($$$$) {
    return unless Irssi::settings_get_bool('pushover_notify_show_privmsg');

    my ($server, $data, $nick, $address) = @_;

    # Do not notify if the address of the active query matches the address of
    # the current message
    return
        if Irssi::active_win->{active}->{address}
        && Irssi::active_win->{active}->{address} eq $address;

    notify("Query","<$nick> $data",0);
}

sub sig_print_text ($$$) {
    return unless Irssi::settings_get_bool('pushover_notify_show_hilight');

    my ($dest, $text, $stripped) = @_;

    # Do not notify if we are in the active window
    return if $dest->{window}->{refnum} == Irssi::active_win()->{refnum};

    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        notify('Hilight',"$dest->{target} $stripped",0);
    }
}

sub sig_client_connect {
    $config{client_count}++;
}

sub sig_client_disconnect {
    $config{client_count}--;
}

Irssi::command_bind('pushover_notify', 'cmd_pushover_notify');
Irssi::command_bind('pushover_notify_test', 'cmd_pushover_notify_test');

Irssi::signal_add_last('message private',           \&sig_message_private);
Irssi::signal_add_last('print text',                \&sig_print_text);
Irssi::signal_add_last('proxy client connected',    \&sig_client_connect);
Irssi::signal_add_last('proxy client disconnected', \&sig_client_disconnect);

Irssi::settings_add_str($IRSSI{'name'},  'pushover_notify_token', '');
Irssi::settings_add_str($IRSSI{'name'},  'pushover_notify_userkey', '');
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_notify_show_privmsg', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_notify_show_hilight', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushover_notify_show_notify', 1);

Irssi::print('%G>>%n '.$IRSSI{'name'}.' '.$VERSION.' loaded (/pushover_notify for help)');
