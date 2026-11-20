#!/usr/bin/perl
# Offline AI Kit - small web server for the chat page on macOS, used when Share on Wi-Fi is on
# (phones cannot open the chat page as a file). Uses only perl modules built into macOS.
#   perl serve-chat.pl --bind 0.0.0.0 --port 8091 --www DIR --logs DIR --ollama-port 11435
# Serves the www folder, /status.json (Wikipedia progress) and /ollama/api/... : a proxy to the
# kit's AI server, which itself only listens on 127.0.0.1. Only chat/listing endpoints pass through.
use strict;
use warnings;
use IO::Socket::INET;
use Cwd qw(realpath);
use POSIX qw(:sys_wait_h);

my %o = (bind => '127.0.0.1', port => 8091, www => '', logs => '', 'ollama-port' => 11435);
while (@ARGV) { my $k = shift @ARGV; $k =~ s/^--//; $o{$k} = shift @ARGV; }
my $root = realpath($o{www}) or die "www folder not found\n";
my %types = (html => 'text/html; charset=utf-8', js => 'text/javascript; charset=utf-8', css => 'text/css; charset=utf-8',
             json => 'application/json; charset=utf-8', png => 'image/png', svg => 'image/svg+xml', ico => 'image/x-icon', txt => 'text/plain; charset=utf-8');
my %allowed = map { $_ => 1 } ('GET /api/tags', 'GET /api/version', 'GET /api/ps', 'POST /api/chat', 'POST /api/generate',
                               'POST /api/show', 'POST /api/embed', 'POST /api/embeddings');
sub logmsg { my $f = "$o{logs}/chat-server-mac.log"; if (open(my $h, '>>', $f)) { print $h scalar(localtime) . " $_[0]\n"; close $h; } }

my $srv = IO::Socket::INET->new(LocalAddr => $o{bind}, LocalPort => $o{port}, Proto => 'tcp', Listen => 64, ReuseAddr => 1)
  or do { logmsg("cannot listen on $o{bind}:$o{port}: $!"); die "cannot listen on $o{bind}:$o{port}: $!\n"; };
logmsg("listening on $o{bind}:$o{port}");
$SIG{CHLD} = sub { 1 while waitpid(-1, WNOHANG) > 0; };
$SIG{TERM} = $SIG{INT} = sub { exit 0; };

while (1) {
  my $c = $srv->accept or next;
  my $pid = fork();
  if (!defined $pid) { close $c; next; }
  if ($pid) { close $c; next; }
  close $srv;
  eval { handle($c); };
  logmsg("request error: $@") if $@;
  close $c;
  exit 0;
}

sub send_resp {
  my ($c, $code, $reason, $ctype, $body, $head) = @_;
  $body = '' unless defined $body;
  my $h = "HTTP/1.1 $code $reason\r\nContent-Type: $ctype\r\nContent-Length: " . length($body) .
          "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n";
  syswrite($c, $h);
  syswrite($c, $body) if length($body) && !$head;
}

sub handle {
  my ($c) = @_;
  local $SIG{ALRM} = sub { die "timeout\n" };
  alarm 15;
  my $first = <$c>; return unless defined $first;
  $first =~ s/\r?\n$//;
  my ($method, $target) = split / /, $first;
  return unless defined $target;
  $method = uc $method;
  my $len = 0;
  while (defined(my $l = <$c>)) { $l =~ s/\r?\n$//; last if $l eq ''; $len = $1 if $l =~ /^content-length:\s*(\d+)/i; }
  my ($path) = split /\?/, $target, 2;
  $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;

  if ($path =~ m{^/ollama(/.*)$}) {
    my $api = $1;
    if ($method eq 'OPTIONS') { send_resp($c, 204, 'No Content', 'text/plain', ''); return; }
    unless ($allowed{"$method $api"}) { send_resp($c, 403, 'Forbidden', 'text/plain', 'Not allowed through the chat page'); return; }
    if ($len > 16 * 1024 * 1024) { send_resp($c, 413, 'Payload Too Large', 'text/plain', ''); return; }
    my $body = '';
    while (length($body) < $len) { my $n = read($c, my $chunk, $len - length($body)); last unless $n; $body .= $chunk; }
    alarm 0;
    my $up = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $o{'ollama-port'}, Proto => 'tcp', Timeout => 10);
    unless ($up) { send_resp($c, 502, 'Bad Gateway', 'application/json', '{"error":"The AI server is not running"}'); return; }
    my $q = ($target =~ /(\?.*)$/) ? $1 : '';
    syswrite($up, "$method $api$q HTTP/1.1\r\nHost: 127.0.0.1:$o{'ollama-port'}\r\nContent-Type: application/json\r\n" .
                  "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n" . $body);
    # Pass the answer back as it arrives (keeps streaming intact).
    my $buf;
    while (1) { my $n = sysread($up, $buf, 16384); last unless $n; my $off = 0; while ($off < $n) { my $w = syswrite($c, $buf, $n - $off, $off); last unless defined $w; $off += $w; } }
    close $up;
    return;
  }

  if ($method ne 'GET' && $method ne 'HEAD') { send_resp($c, 405, 'Method Not Allowed', 'text/plain', ''); return; }
  my $head = $method eq 'HEAD';
  if ($path eq '/status.json') {
    my $json = '{"state":"unknown"}';
    if (open(my $h, '<', "$o{logs}/wikipedia-progress.json")) { local $/; my $t = <$h>; close $h; $json = $t if defined $t && $t =~ /\S/; }
    send_resp($c, 200, 'OK', 'application/json; charset=utf-8', $json, $head);
    return;
  }
  $path = '/chat.html' if $path eq '/';
  my $full = realpath($root . $path);
  if (!defined $full || index($full, "$root/") != 0 || !-f $full) { send_resp($c, 404, 'Not Found', 'text/plain', 'Not found'); return; }
  my ($ext) = $full =~ /\.([A-Za-z0-9]+)$/;
  my $ct = $types{lc($ext // '')} // 'application/octet-stream';
  open(my $fh, '<:raw', $full) or do { send_resp($c, 404, 'Not Found', 'text/plain', 'Not found'); return; };
  local $/; my $data = <$fh>; close $fh;
  send_resp($c, 200, 'OK', $ct, $data, $head);
}
