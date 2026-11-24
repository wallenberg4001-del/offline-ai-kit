#!/bin/bash
# Prints a JSON array of external physical disks the guided installer can prepare.
# The startup disk is omitted. Nothing is erased and nothing is downloaded.
# Fields: id, sizeGB, internal, startup, partitions[{id, name, format, sizeGB, mount}].
# shellcheck disable=SC2016
perl -MJSON::PP -e '
use strict;
use warnings;
use JSON::PP qw(decode_json encode_json);
my $os = `uname -s 2>/dev/null`;
chomp $os;

sub capture {
  my @cmd = @_;
  my $pid = open(my $fh, "-|", @cmd);
  return "" unless $pid;
  local $/;
  my $out = <$fh> // "";
  close $fh;
  return $? == 0 ? $out : "";
}
sub field {
  my ($text, $label) = @_;
  return "" unless defined $text && $text =~ /^\s*\Q$label\E:\s*(.*?)\s*$/m;
  return $1;
}
sub gb {
  my ($bytes) = @_;
  return 0 unless defined $bytes && "$bytes" =~ /^\d+(?:\.\d+)?$/;
  return 0 + sprintf("%.1f", $bytes / 1000000000);
}
sub jfalse { return JSON::PP::false; }
sub clean_mount {
  my ($mount) = @_;
  return "" unless defined $mount;
  return "" if $mount eq "" || $mount eq "Not Mounted" || $mount =~ /^Not applicable/;
  return $mount;
}

if ($os eq "Darwin") {
  my $root = capture("diskutil", "info", "/");
  my $whole = field($root, "Part of Whole");
  my $phys = field($root, "APFS Physical Store");
  $phys = field($root, "Physical Store") if $phys eq "";
  my $phys_disk = $phys;
  $phys_disk =~ s/s\d.*\z//;
  my %skip = map { $_ => 1 } grep { length } ($whole, $phys, $phys_disk);

  my $plist = `diskutil list -plist external physical 2>/dev/null | plutil -convert json -o - - 2>/dev/null`;
  my $data = eval { decode_json($plist || "{}") } || {};
  my $apfs_raw = `diskutil apfs list -plist 2>/dev/null | plutil -convert json -o - - 2>/dev/null`;
  my $apfs = eval { decode_json($apfs_raw || "{}") } || {};
  my %by_store;
  for my $container (@{$apfs->{Containers} || []}) {
    my (@names, @vols);
    for my $vol (@{$container->{Volumes} || []}) {
      my $roles = $vol->{Roles};
      my $role = (ref $roles eq "ARRAY" && @$roles) ? ($roles->[0] // "") : "";
      next if $role eq "Preboot" || $role eq "Recovery" || $role eq "VM";
      my $name = $vol->{Name} || "";
      next if $name eq "" || $name eq "Preboot" || $name eq "Recovery" || $name eq "VM";
      push @names, $name;
      push @vols, $vol->{DeviceIdentifier} if $vol->{DeviceIdentifier};
    }
    for my $store (@{$container->{PhysicalStores} || []}) {
      my $sid = $store->{DeviceIdentifier} || "";
      next if $sid eq "";
      $by_store{$sid} = { names => [@names], vols => [@vols] };
    }
  }

  my @out;
  for my $disk (@{$data->{AllDisksAndPartitions} || []}) {
    my $id = $disk->{DeviceIdentifier} || "";
    next if $id eq "" || $skip{$id} || $id !~ /\Adisk\d+\z/;
    my $info = capture("diskutil", "info", $id);
    next if $info eq "";
    next unless field($info, "Device Location") eq "External";
    my @parts;
    for my $part (@{$disk->{Partitions} || []}) {
      my $content = $part->{Content} || "";
      next if $content =~ /\A(?:EFI|Microsoft Reserved|Apple_Boot)\z/i;
      next if $content =~ /free space/i;
      my $pid = $part->{DeviceIdentifier} || "";
      next if $pid eq "" || $pid !~ /\A\Q$id\Es\d+\z/;
      my $name = $part->{VolumeName} || "";
      my $format = "";
      my $mount = clean_mount($part->{MountPoint} || "");
      if ($content eq "Apple_APFS") {
        my $stored = $by_store{$pid};
        $format = "APFS";
        if ($stored && @{$stored->{names}}) { $name = join(", ", @{$stored->{names}}); }
        $name = "APFS" if $name eq "";
        if ($mount eq "" && $stored) {
          for my $vol (@{$stored->{vols}}) {
            last if $vol !~ /\Adisk\d+s\d+\z/;
            my $vi = capture("diskutil", "info", $vol);
            $mount = clean_mount(field($vi, "Mount Point"));
            last if $mount ne "";
          }
        }
      } else {
        my $pinfo = capture("diskutil", "info", $pid);
        $format = field($pinfo, "File System Personality");
        $format = $content if $format eq "";
        $name = field($pinfo, "Volume Name") if $name eq "";
        $mount = clean_mount(field($pinfo, "Mount Point")) if $mount eq "";
      }
      $name = $pid if $name eq "";
      push @parts, {
        id => $pid, name => $name, format => $format,
        sizeGB => gb($part->{Size}), mount => $mount
      };
    }
    push @out, {
      id => $id, sizeGB => gb($disk->{Size}),
      internal => jfalse(), startup => jfalse(), partitions => \@parts
    };
  }
  print encode_json(\@out), "\n";
  exit 0;
}

my $ls = `lsblk -b -J -o NAME,SIZE,TYPE,TRAN,RM,HOTPLUG,FSTYPE,LABEL,MOUNTPOINT,PKNAME,PARTTYPENAME 2>/dev/null`;
my $tree = eval { decode_json($ls || "") };
if (!$tree || ref $tree ne "HASH") { print "[]\n"; exit 0; }
my $root_src = `findmnt -no SOURCE / 2>/dev/null`;
chomp $root_src;
$root_src =~ s/\s.*\z//;
my $root_disk = "";
if ($root_src ne "") {
  $root_disk = `lsblk -no PKNAME \Q$root_src\E 2>/dev/null`;
  chomp $root_disk;
  $root_disk =~ s/\s.*\z//;
  if ($root_disk eq "") {
    $root_disk = $root_src;
    $root_disk =~ s{.*/}{};
    $root_disk =~ s/p?\d+\z//;
  }
}
my @out;
for my $dev (@{$tree->{blockdevices} || []}) {
  next unless ($dev->{type} || "") eq "disk";
  my $tran = $dev->{tran} || "";
  my $rm = defined $dev->{rm} ? "$dev->{rm}" : "0";
  my $hot = defined $dev->{hotplug} ? "$dev->{hotplug}" : "0";
  next unless $tran eq "usb" || $rm eq "1" || $hot eq "1";
  my $name = $dev->{name} || "";
  next if $name eq "" || $name eq $root_disk;
  next unless $name =~ /\A(?:sd[a-z]+|nvme\d+n\d+|mmcblk\d+)\z/;
  my @parts;
  for my $part (@{$dev->{children} || []}) {
    next unless ($part->{type} || "") eq "part";
    my $kind = $part->{parttypename} || "";
    next if $kind =~ /EFI|Microsoft reserved|BIOS boot/i;
    my $label = $part->{label} || "";
    next if $label eq "EFI";
    my $pid = $part->{name} || "";
    next if $pid eq "" || $pid !~ /\A\Q$name\E(?:p?\d+)\z/;
    my $mount = $part->{mountpoint};
    $mount = "" if !defined $mount || ref $mount;
    push @parts, {
      id => $pid,
      name => ($label ne "" ? $label : $pid),
      format => ($part->{fstype} || ""),
      sizeGB => gb($part->{size}),
      mount => $mount
    };
  }
  push @out, {
    id => $name, sizeGB => gb($dev->{size}),
    internal => jfalse(), startup => jfalse(), partitions => \@parts
  };
}
print encode_json(\@out), "\n";
'
