#!/usr/bin/perl
# Guided installer for Mac and Linux. Opens a browser on this computer only.
# The page explains every choice. Install runs mac/setup.sh with those answers.
# Nothing is downloaded until the page says Install. Linux launchers set OFFLINE_AI_OS=linux.
use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP qw(decode_json encode_json);
use POSIX qw(WNOHANG);
use FindBin qw($Bin);

my $KIT = $Bin;
$KIT =~ s{/mac$}{};
my $WWW = "$KIT/www";
my $LOG = "$KIT/logs/install-gui.log";
my $install_pid = 0;
my $install_exit;

$| = 1;

my $server;
my $port = 0;
for my $try (8092 .. 8095) {
    $server = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1', LocalPort => $try,
        Type => SOCK_STREAM, Reuse => 1, Listen => 5,
    );
    if ($server) { $port = $try; last; }
}
die "Could not open the guided installer (ports 8092-8095 are in use).\nUse SETUP instead. It asks the same questions in a text window.\n" unless $server;

my $url = "http://127.0.0.1:$port/";
print "Guided installer is open in your web browser:\n  $url\n";
print "Leave this window open. Closing it stops the installer.\n";
print "Nothing is downloaded until you press Install on the last screen.\n";
if (!$ENV{OFFLINE_AI_NO_BROWSER}) {
    if (($ENV{OFFLINE_AI_OS} || '') eq 'linux') { system 'xdg-open', $url; }
    else { system 'open', $url; }
}

while (my $client = $server->accept()) {
    $client->autoflush(1);
    eval { handle($client); };
    warn "request error: $@\n" if $@;
    close $client;
}

sub handle {
    my ($client) = @_;
    my $req = <$client>;
    return unless defined $req;
    my %hdr;
    while (defined(my $line = <$client>)) {
        $line =~ s/\r?\n\z//;
        last if $line eq '';
        $hdr{lc $1} = $2 if $line =~ /^([^:]+):\s*(.*)$/;
    }
    my ($method, $path) = $req =~ /^(\w+)\s+(\S+)/;
    $path ||= '/';
    $path =~ s/\?.*\z//;
    my $len = $hdr{'content-length'} || 0;
    my $body = '';
    if ($len > 0 && $len < 1_000_000) {
        read($client, $body, $len) or $body = '';
    }
    reap();
    if ($method eq 'GET' && ($path eq '/' || $path eq '/install-wizard.html')) {
        return send_file($client, "$WWW/install-wizard.html", 'text/html; charset=utf-8');
    }
    if ($method eq 'GET' && $path eq '/install-wizard.js') {
        return send_file($client, "$WWW/install-wizard.js", 'text/javascript; charset=utf-8');
    }
    if ($method eq 'GET' && $path eq '/catalog/extra-libraries.txt') {
        return send_file($client, "$KIT/catalog/extra-libraries.txt", 'text/plain; charset=utf-8');
    }
    if ($method eq 'GET' && $path eq '/catalog/maps.txt') {
        return send_file($client, "$KIT/catalog/maps.txt", 'text/plain; charset=utf-8');
    }
    if ($method eq 'GET' && $path eq '/api/context') {
        my $json = `bash "$KIT/mac/wizard-context.sh"`;
        if ($? != 0 || $json !~ /"os"/) {
            return respond($client, 500, 'application/json; charset=utf-8', '{"error":"Could not look at this computer."}');
        }
        return respond($client, 200, 'application/json; charset=utf-8', $json);
    }
    if ($method eq 'GET' && $path eq '/api/log') {
        reap();
        my $text = read_log();
        my $running = $install_pid ? 1 : 0;
        my $payload = { running => $running, text => $text };
        $payload->{exit} = $install_exit if defined $install_exit;
        return respond($client, 200, 'application/json; charset=utf-8', encode_json($payload));
    }
    if ($method eq 'POST' && $path eq '/api/install') {
        return respond($client, 409, 'text/plain; charset=utf-8', "An install is already running.\n") if $install_pid;
        my $data = eval { decode_json($body) };
        return respond($client, 400, 'text/plain; charset=utf-8', "The choices could not be read.\n") unless $data;
        my $err = validate($data);
        return respond($client, 400, 'text/plain; charset=utf-8', "$err\n") if $err;
        my @cmd = ('bash', "$KIT/mac/setup.sh", '--yes');
        push @cmd, '--models', $data->{models} if defined $data->{models} && $data->{models} ne '';
        push @cmd, '--tier', $data->{tier};
        push @cmd, ($data->{wikipedia} ? '--with-wikipedia' : '--skip-wikipedia');
        my $extras = id_list($data->{extras});
        my $maps = id_list($data->{maps});
        push @cmd, '--extra-libraries', $extras if $extras ne '';
        push @cmd, '--maps', $maps if $maps ne '';
        push @cmd, ($data->{shareWifi} ? '--share-wifi' : '--no-share-wifi');
        push @cmd, ($data->{universal} ? '--universal' : '--this-computer');
        my $start_err = start_install(@cmd);
        return respond($client, 500, 'text/plain; charset=utf-8', "$start_err\n") if $start_err;
        return respond($client, 200, 'application/json; charset=utf-8', '{"ok":true}');
    }
    respond($client, 404, 'text/plain; charset=utf-8', "Not found.\n");
}

sub validate {
    my ($data) = @_;
    my $models = defined $data->{models} ? $data->{models} : '';
    return 'Choose an AI size.' if $models ne '' && $models !~ /\A(?:lite|8|16|24|32|0|1|2|core|full|[A-Za-z0-9_.:-]+(?:,[A-Za-z0-9_.:-]+)*)\z/;
    my $tier = defined $data->{tier} ? $data->{tier} : '';
    return 'Choose a library.' unless $tier =~ /\A(?:1|2|essentials|recommended)\z/;
    for my $key (qw(extras maps)) {
        my $list = $data->{$key};
        $list = [] unless ref $list eq 'ARRAY';
        for my $id (@$list) {
            return 'A choice was not recognised.' unless defined $id && $id =~ /\A[a-z0-9-]+\z/;
        }
    }
    return '';
}

sub id_list {
    my ($list) = @_;
    return '' unless ref $list eq 'ARRAY';
    return join(',', @$list);
}

sub start_install {
    my (@cmd) = @_;
    mkdir "$KIT/logs";
    open my $logfh, '>', $LOG or return 'Cannot write the install log.';
    my $pid = fork();
    return 'Could not start the installer.' unless defined $pid;
    if ($pid == 0) {
        open STDOUT, '>&', $logfh or exit 1;
        open STDERR, '>&', STDOUT or exit 1;
        $| = 1;
        chdir $KIT or exit 1;
        exec {$cmd[0]} @cmd;
        exit 1;
    }
    close $logfh;
    $install_pid = $pid;
    $install_exit = undef;
    return '';
}

sub reap {
    return unless $install_pid;
    my $got = waitpid($install_pid, WNOHANG);
    return unless $got == $install_pid;
    $install_exit = $? >> 8;
    $install_pid = 0;
}

sub read_log {
    return '' unless -f $LOG;
    open my $fh, '<', $LOG or return '';
    local $/;
    my $text = <$fh> // '';
    close $fh;
    $text = substr($text, -20000) if length $text > 20000;
    return $text;
}

sub send_file {
    my ($client, $path, $type) = @_;
    return respond($client, 404, 'text/plain; charset=utf-8', "Missing file.\n") unless -f $path;
    open my $fh, '<', $path or return respond($client, 500, 'text/plain; charset=utf-8', "Cannot read file.\n");
    binmode $fh;
    local $/;
    my $body = <$fh>;
    close $fh;
    respond($client, 200, $type, $body);
}

sub respond {
    my ($client, $code, $type, $body) = @_;
    $body = '' unless defined $body;
    my %msg = (200 => 'OK', 400 => 'Bad Request', 404 => 'Not Found', 409 => 'Conflict', 500 => 'Error');
    my $msg = $msg{$code} || 'OK';
    my $len = length $body;
    print $client "HTTP/1.0 $code $msg\r\nContent-Type: $type\r\nContent-Length: $len\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n";
    print $client $body;
}
