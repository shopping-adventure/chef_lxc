set[:container] = {
  :base_directory => '/home/containers',
  :default => {
    :domain => "vm.local", 
    :variant => 'minbase',
    :suite => 'precise',
    :mirror => "http://fr.archive.ubuntu.com/ubuntu/",
    :packages => %w(ifupdown locales netbase net-tools iproute openssh-server console-setup iputils-ping wget gnupg ethtool ucf ruby-dev curl sudo),
    :ipv4 => {
      :cidr => '192.168.168.100/24'
    }
  }
}

# ipv4.address will be used as gateway for guest
set[:bridges] = {
  :vmbr0 => {
    :nat => true,
    :ipv4 => {
      :address  => '192.168.168.1',
      :netmask  => '255.255.255.0',
      :broadcast => '192.168.168.255'
    }
  }
}

#By default no btrfs partition
default['btrfs']['activate'] = false

# If a partition exist :
default['btrfs']['physical_devices'] = [ "/dev/sd1","/dev/sd2" ]
