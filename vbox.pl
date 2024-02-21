#!/usr/bin/env perl
# vbox.pl - obtain inventory from running VirtualBox machines
# MIT License - javier.rodriguez@sinensia.com
use warnings;
use strict;
use JSON qw/encode_json/;

my $VBOX = "VBoxManage";
my $inv = {};
my (%groups);
my $running = `$VBOX list runningvms`;
if($ARGV[0] && $ARGV[0]=~m/^-?-h(elp)?/) {
  help();
}
my $verbose = $ARGV[0] && ($ARGV[0] =~ m/^-?-v(erbose)?/);
foreach my $line (split(/\n/, $running)) {
  chomp($line);
  if ($line =~ m/"(.*?)" \{(.*?)\}/) {
    my ($name, $uuid) = ($1, $2);
    my $host = {
      ansible_user => 'vagrant', # default userid
    };
    my $os = 'other';
    print STDERR "$name $uuid\n" if $verbose;
    my $info = `$VBOX showvminfo $uuid --machinereadable --details`;
    foreach my $v (split(/\n/, $info)) {
      chomp($v);
      $v =~ s,^\s+,,; # trim leading spaces
      my ($var, $val) = split(/=/, $v, 2);
      $val =~ s/^"(.*)"$/$1/ if $val; # unquote string
      print STDERR "  $var=[$val]\n" if $verbose;
      if ($var =~ m/forward/i) {
        # e.g. "ssh,tcp,127.0.0.1,2200,,22"
        my ($svc, $proto, $host_ip, $host_port, $guest_ip, $guest_port) = split(/,/, $val);
        if ($svc eq 'ssh') {
          $host->{ansible_host} = $host_ip;
          $host->{ansible_port} = $host_port;

        }
      } elsif ($var =~ m/SharedFolderPathMachineMapping1/) {
        # default mapping
        $host->{ansible_private_key_file} = "$val/.vagrant/machines/default/virtualbox/private_key";
      } elsif ($var eq 'ostype') {
        # save OS type to determine host group
        $os = $val;
      }
    }
    my $group = $os =~ m/^debian|ubuntu/i ? 'debians'
      : $os =~ m/^redhat|centos|fedora/i ? 'redhats'
      : 'other';
    ++$groups{$group};
    # save host vars
    $inv->{_meta}{hostvars}{$name} = $host;
    # add to group
    push @{$inv->{$group}{hosts}}, $name;
  }
}
$inv->{all}{children} = [ sort keys %groups ];

print encode_json($inv);


sub help {
  print <<EOH;
Usage: $0 [-h|-v]
       Returns ansible inventory file for running VirtualBox machines.
       e.g.
         ansible-inventory -i $0 --list
         ansible-playbook -i $0 {playbook}
         ansible -i $0 -m ping all
EOH
  exit 255;
}
