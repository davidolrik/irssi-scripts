#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use vars qw($VERSION %IRSSI %config);

use Irssi;

use DateTime;
use Mojo::UserAgent;
use Mojo::Util qw[trim];
use Unicode::String qw[utf8 latin1];

$VERSION = '0.02';
%IRSSI = (
    authors         =>      'David Jack Wange Olrik',
    contact         =>      'djo@cpan.org',
    name            =>      'push4_notify',
    description     =>      'Sends out push notifications to your iPhone from Irssi via appnotifications.com.',
    license         =>      'Artistic',
    url             =>      'http://david.olrik.dk/',
);

sub cmd_push4_notify ($$$) {
    Irssi::print('%G>>%n Push4 notify can be configured using settings:');
    Irssi::print('%G>>%n push4_notify_apikey       : Your Push4 apikey - needed for this to work, see yours at https://www.appnotifications.com/account/edit');
    Irssi::print('%G>>%n push4_notify_show_privmsg : Notify about private messages.');
    Irssi::print('%G>>%n push4_notify_show_hilight : Notify when your name is hilighted.');
    Irssi::print('%G>>%n push4_notify_sound        : Which sound to play on your iPhone.');
    Irssi::print('%G>>%n push4_notify_show_notify  : Notify when someone on your away list joins or leaves.');
}

sub cmd_push4_notify_test ($$$) {
    notify("Test","This is a test",1);
}

sub notify {
    my ($event,$text,$priority) = @_;
    $priority = 0 unless defined($priority);

    # Don't send push notifications when unconfigured
    return unless Irssi::settings_get_str('push4_notify_apikey');

    # Don't send push notifications when a proxy client is connected
    return if $config{proxy_client_count};

    my $message = sprintf("<b>%s</b> %s",DateTime->now(time_zone => 'local')->hms,$text);
    my $message_preview = $text;
    if ( length($text) > 20 ) {
        $message_preview = substr($text,0,20) . '…';
    }

    my $sound = Irssi::settings_get_str('push4_notify_sound') || 1;
    my $params = {
        "user_credentials"                   => Irssi::settings_get_str('push4_notify_apikey'),
        "notification[message]"              => "Irssi - $event", # Notification view: Title
        "notification[long_message]"         => $message,         # Notification view: Full message
        "notification[title]"                => "Irssi - $event", # List view: Title
        "notification[long_message_preview]" => $message_preview, # List view: Message preview
        "notification[message_level]"        => $priority, # [-2..2],
        "notification[silent]"               => "0",
        "notification[action_loc_key]"       => "Read",
        "notification[sound]"                => $sound,
    };

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post('https://www.appnotifications.com/account/notifications.json' => form => $params);
    if (my $res = $tx->success) {
        # NOP
    }
    else {
        my ($err, $code) = $tx->error;
        my $error_message = $code ? "$code response: $err" : "Connection error: $err";
        Irssi::print("\%RError in push4_notify:\%n $error_message.");
    }
}

sub sig_message_private ($$$$) {
    return unless Irssi::settings_get_bool('push4_notify_show_privmsg');

    my ($server, $data, $nick, $address) = @_;

    # Do not notify if the address of the active query matches the address of
    # the current message
    return
        if Irssi::active_win->{active}->{address}
        && Irssi::active_win->{active}->{address} eq $address;

    notify("Query from $nick","<$nick> $data",1);
}

sub sig_print_text ($$$) {
    return unless Irssi::settings_get_bool('push4_notify_show_hilight');

    my ($dest, $text, $stripped) = @_;

    # Do not notify if we are in the active window
    return if $dest->{window}->{refnum} == Irssi::active_win()->{refnum};

    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        notify('Hilight',"$dest->{target} $stripped",1);
    }
}

sub sig_client_connect {
    $config{client_count}++;
}

sub sig_client_disconnect {
    $config{client_count}--;
}

Irssi::command_bind('push4_notify', 'cmd_push4_notify');
Irssi::command_bind('push4_notify_test', 'cmd_push4_notify_test');

Irssi::signal_add_last('message private',           \&sig_message_private);
Irssi::signal_add_last('print text',                \&sig_print_text);
Irssi::signal_add_last('proxy client connected',    \&sig_client_connect);
Irssi::signal_add_last('proxy client disconnected', \&sig_client_disconnect);

Irssi::settings_add_str($IRSSI{'name'},  'push4_notify_apikey', '');
Irssi::settings_add_str($IRSSI{'name'},  'push4_notify_sound', '1');
Irssi::settings_add_bool($IRSSI{'name'}, 'push4_notify_show_privmsg', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'push4_notify_show_hilight', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'push4_notify_show_notify', 1);

Irssi::print('%G>>%n '.$IRSSI{'name'}.' '.$VERSION.' loaded (/push4_notify for help)');
