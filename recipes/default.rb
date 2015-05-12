#
# Cookbook Name:: lxc
# Recipe:: default
#
# Copyright 2015, KBRW Adventure 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


package 'debootstrap'
package 'apt-cacher-ng'
package 'inotify-tools'

chef_gem 'netaddr'
node.default[:vlanid] = 666 

include_recipe 'lxc::manage'
include_recipe 'lxc::network_bridge'

host = node[:container]

machines = search(:virtual_machines, "host:#{node['fqdn']}")

directory host[:base_directory] do
  action :create
  mode '0755'
  owner 'root'
  group 'root'
end

template "#{host[:base_directory]}/main.conf" do
  source 'tools/main.conf.erb'
  mode '0644'
  owner 'root'
  group 'root'
  variables :machines => machines
end

template '/usr/bin/lxc-shutdown-agent' do
  source 'tools/lxc-shutdown-agent.erb'
  mode '0755'
  owner 'root'
  group 'root'
end


template '/usr/bin/lxc-start-vm' do
  source 'tools/lxc-start-vm.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-stop-vm' do
  source 'tools/lxc-stop-vm.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-start-all' do
  source 'tools/lxc-start-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-shutdown-all' do
  source 'tools/lxc-shutdown-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-status-all' do
  source 'tools/lxc-status-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/bin/lxc-kill-all' do
  source 'tools/lxc-kill-all.erb'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/etc/init/lxc.conf' do
  source 'init-lxc.conf.erb'
  mode '0644'
  owner 'root'
  group 'root'
end

bash "add custom ohai plugins" do
  not_if "grep ohai_plugins /etc/chef/client.rb"
  code <<-EOSH
    echo "Ohai::Config[:plugin_path] << '/etc/chef/ohai_plugins'" >> /etc/chef/client.rb
  EOSH
end

directory "/etc/chef/ohai_plugins" do
  action :create
  owner 'root'
  group 'root'
  mode '0755'
end


cookbook_file "/etc/chef/ohai_plugins/virtualization_lxc.rb"

# Followed instruction from
# http://blog.bodhizazen.net/linux/lxc-configure-ubuntu-lucid-containers/
btrfs_mount_line=[]
machines.each do |guest|
  # Bootstrap
  domain = guest[:domain] || host[:default][:domain]
  hostname = "#{guest[:id]}.#{domain}"

  variant = guest[:variant] ||= host[:default][:variant]
  suite   = guest[:suite  ] ||= host[:default][:suite  ]
  mirror  = guest[:mirror ] ||= host[:default][:mirror ]
  packages= guest[:packages] ||= host[:default][:packages]

  home = "#{host[:base_directory]}/#{guest[:id]}"
  rootfs  =  "#{home}/rootfs"
  guestslug = guest[:private_ipv4][/[0-9]*\//][/[0-9]*/]

  execute "debootstrap-#{guest[:id]}" do
    command "debootstrap --variant=#{variant} --include #{packages.join(',')} #{suite} #{rootfs} #{mirror}"
    action :run
    not_if "test -f #{rootfs}/etc/issue"
  end

  #

  guestfqdn=guest["id"]+"."+guest["domain"]
  vm = begin Chef::Node.load(guestfqdn) rescue nil end
  unless vm == nil
    # Set hypervisor name inside VM
    hyp=node["hostname"]+".provider.name"
    vm.default["virtualization"]["hypervisor"]=hyp
    vm.save
  end
  #Default var
  tabdir = []	
  data_path = "" 
  megadir={}
  if guest[:big_dirs].nil?
    megadir={}
  else
    megadir = guest[:big_dirs].clone
  end

  # Not for qa node
  unless ( guest['id'].include? "prefix-" or node["virtualization"]["provider"] != "providerA" )
    megadir[:"backup"] = {"path"=>"/srv/backup/", "options"=>"bind,rw"}
  end
  guest[:big_dirs] = megadir
  if node[:mixhd] and guest[:big_dirs]
    big_dir_path=node["mixhd"]["bighd_path"]
    #Default data path, we will surcharged if btrfs
    data_path = big_dir_path 
    path=""
    options=""
    options_btrfs=""
    device=""

    hash = {}

    # Chef::Log.warn("LX0 ")
    (guest[:big_dirs] or {}).each do |key,val|
      device="#{key}".to_s
      #Chef::Log.warn("LXC1 : #{key} - #{val}")

      (guest[:big_dirs]["#{key}"] or {}).each do |code,value|
        #Chef::Log.warn("LXC2 : #{code} - #{value}")
        if code.include? "options" then options = "#{value}".to_s end
        if code.include? "options_btrfs" then options_btrfs = "#{value}".to_s end
        if code.include? "path" then  path= "#{value}".to_s end
      end
      #Chef::Log.warn("LXC3 : path=#{path} dev=#{device} option=#{options} option_btrfs=#{options_btrfs} ")

      bigdir = { "PATH" => "#{path}", "DEVICE" => "#{device}", "OPTIONS" => "#{options}", "OPTIONS_BTRFS" => "#{options_btrfs}" }
      tabdir.push bigdir

      if search(:node,"hostname:#{guest['id']}").first
        guestfqdn=guest["id"]+"."+guest["domain"]
        vm = begin Chef::Node.load(guestfqdn) rescue nil end
        unless vm == nil
          # Set hypervisor name inside VM
          hyp=node["hostname"]+".provider.name"
          vm.default["virtualization"]["hypervisor"]=hyp
          # We generate bid_dir info inside the VM, if the VM exist
          vm.default["btrfs"]["slowhdd"]["#{key}"]["inpath"] = path
          vm.default["btrfs"]["slowhdd"]["device"]= node["btrfs"]["physical_devices"].first
          vm.default["btrfs"]["slowhdd"]["#{key}"]["outpath"] = big_dir_path +"/virtualmachine_data/"+ guest['id'] +"_"+ device

          vm.save
        end	
      end	

      #Mount point inside VM
      directory "#{rootfs}/#{path}" do
        action :create
        owner 'root'
        group 'root'
        mode '0755'
        recursive true
        not_if "test -d #{rootfs}/#{path}"
      end

      #BTRFS file system
      if node['btrfs']['activate'] == true
        include_recipe 'btrfs'
        data_path = big_dir_path + "/" + "virtualmachine_data"

        #Assure that all needed dir exists
        #All btrfs nativ are here
        directory "/btrfs" do
          action :create
          not_if "test -d /btrfs"
        end

        #Root point of data
        directory "#{data_path}" do
          action :create
          not_if "test -d #{data_path}"
          recursive true
        end

        #Create the BIGDIR subvolume in /btrfs dir
        #btrfs_btrfs "#{guest['id']}_create_subvol" do
        btrfs_btrfs "#{guest['id']}_#{device}_create_subvol" do
          pathdir "/btrfs"
          #name "#{guest['id']}"
          name "#{guest['id']}_#{device}"
          action :create_subvolume
        end

        #Mount the BIGDIR subvolume into #{data_path} dir
        #btrfs_btrfs "#{guest['id']}_mount_device" do
        btrfs_btrfs "#{guest['id']}_#{device}_mount_device" do
          device_source node['btrfs']['physical_devices'].first
          #subvol_name "#{guest['id']}"
          subvol_name "#{guest['id']}_#{device}"
          device_dest "#{data_path}/#{guest['id']}_#{device}"
          mount_opt "#{options_btrfs}"
          action :mount_device
          btrfs_mount_line << "mount -t btrfs -o subvol=#{subvol_name}#{mount_opt} #{device_source} #{device_dest}"
        end

      else
        #Non BTRFS file system
        #directory "/data/virtualmachine_data/#{device}" do
        directory "/#{data_path}/#{device}" do
          action :create
          owner 'root'
          group 'root'
          mode '0755'
          recursive true
          not_if "test -d /#{data_path}/#{device}"
          #not_if "test -d /data/virtualmachine_data/#{device}"
        end
      end
    end
  end
  #	
  #	mount "#{rootfs}#{path}" do
  #			device "#{node[:mixhd]['bighd_path']}/#{device}"
  #			fstype "none"
  #			options "#{options}"
  #			action [:mount, :enable]
  #		end
  #	end

  ## tabdir.each do |tableau| 
  ##   Chef::Log.warn("LXC Tableau for #{hostname} : #{tableau}")
  ## end

  ipv6gw=""
  if guest[:public_ipv6]
    require 'netaddr'
    first_part = (NetAddr.unshorten((NetAddr::CIDR.create guest[:public_ipv6]).to_s.split('/',2).first)).to_s.split(':')[0..2].join(":")
    subnet = search(:subnets, "cidr:#{first_part.to_s.gsub(':','\:')}*")
    ipv6gw = "#{subnet.first['gw'].to_s}"
  end
  template "#{home}/config" do
    source "lxc.conf.erb"
    variables :vlanid => node[:vlanid], :guestslug => guestslug, :host => host, :guest => guest, :home => home, :rootfs => rootfs, :hostname => hostname, :bigdir => tabdir, :ipv6gw => ipv6gw, :data_path => data_path
    action :create
  end

  template "#{home}/fstab" do
    source 'fstab.erb'
    variables :host => host, :guest => guest, :rootfs => rootfs, :hostname => hostname
    action :create
  end

  file "#{rootfs}/etc/inittab" do
    action :delete
  end

  file "#{rootfs}/etc/hostname" do
    backup false
    content hostname
    action :create
  end

  file "#{rootfs}/etc/hosts" do
    backup false
    action :create
    content %Q~127.0.0.1 #{hostname} #{guest[:id]} localhost\n::1 #{hostname} #{guest[:id]} localhost\n~
  end

  file "#{rootfs}/etc/resolv.conf" do
    backup false
    action :create
    not_if "ls #{rootfs}/etc/dnsmasq.conf"
    content %Q~nameserver 1.1.1.1\n~
  end

  template "#{rootfs}/etc/apt/sources.list" do
    source 'rootfs/sources.list.erb'
    variables :host => host, :guest => guest
  end

  bash "remove as many init scripts as possible on #{guest[:id]}" do
    only_if %Q~test -f #{rootfs}/etc/init/hwclock.conf~
    code <<-EOSH
      rm #{rootfs}/etc/init/{hwclock,mount,plymouth,udev,network,tty5,tty6}*
      true
    EOSH
  end

  bash "remove pointless services on #{guest[:id]}" do
    only_if %Q'test -f #{rootfs}/etc/rc0.d/S*umountfs'
    code <<-EOSH
      chroot #{rootfs} /usr/sbin/update-rc.d -f umountfs remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f hwclock.sh remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f hwclockfirst.sh remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f umountroot remove
      chroot #{rootfs} /usr/sbin/update-rc.d -f ondemand remove
    EOSH
  end

  template "#{rootfs}/etc/init/vm.conf" do
    source 'rootfs/init-vm.conf.erb'
    action :create
  end

  #Recherche des passerelle des gw
  vpngw6=""
  vpngw4=""
  gateway={}
  if node["virtualization"]["provider"] == "providerA"
    require 'ipaddr'
    # Node a une ip publique
    if (guest[:public_ipv4])
    gateway[:ip] = IPAddr.new(guest[:public_ipv4]).to_range.to_a.last(2).first.to_s
    gateway[:dev] = "public"
    else
    # Node n'a pas d'ip publique => sort pas son host
    gateway[:ip] = node[:cloud][:local_ipv4]
    gateway[:dev] = "private"
    end
    vpn = search(:apps, "id:vpn_A").first
    vpngw6 = vpn["vrrp"]["_default"]["instances"]["private"]["ipv6"]
    vpngw4 = vpn["vrrp"]["_default"]["instances"]["private"]["ipv4"]
  end
  if node["virtualization"]["provider"] == "providerB"
    vpn = search(:apps, "id:vpn_providerB").first
    vpngw6 = vpn["vrrp"]["_default"]["instances"]["private"]["ipv6"]
    vpngw4 = vpn["vrrp"]["_default"]["instances"]["private"]["ipv4"]
  end

  template "#{rootfs}/etc/init/vm-net.conf" do
    source 'rootfs/init-net.conf.erb'
    variables :host => node, :guest => guest, :gateway => gateway, :ipv6gw => ipv6gw, :vpngw4 => vpngw4, :vpngw6 => vpngw6
  end
  template "#{rootfs}/etc/init/vm-power.conf" do
    source 'rootfs/vm-power.conf.erb'
    variables :host => node
  end

  template "#{rootfs}/usr/bin/chef-bootstrap" do
    source 'rootfs/install-chef.sh.erb'
    variables :host => host, :guest => guest, :codename => suite
    mode '0755'
  end

  template "#{rootfs}/etc/init/container-detect.conf" do
    source 'rootfs/container-detect.conf'
    variables :host => host
  end

  directory "#{rootfs}/etc/chef" do
    action :create
    owner 'root'
    group 'root'
    mode '0755'
  end

  directory "#{rootfs}/etc/chef/ohai_plugins" do
    action :create
    owner 'root'
    group 'root'
    mode '0755'
  end

  #Ohai plugins per cloud provider
  node_provider=""
  node.run_list.roles.each do |myrole|
    if myrole.include?("roleA")
      node_provider="providerA"
    end
    if myrole.include?("roleB")
      node_provider="providerB"
    end
  end

  cookbook_file "#{rootfs}/etc/chef/ohai_plugins/virtualization_lxc.rb" 
  cookbook_file "#{rootfs}/etc/chef/ohai_plugins/customcloud.rb" 

  file "#{rootfs}/etc/chef/base.json" do
    backup false
    action :create
    content %Q~{ "run_list": ["role[base]","role[last]"]}~
  end

  chef_private_key = "#{rootfs}/etc/chef/client.pem"
  chef_archived_key = "#{home}/chef-client.pem"
  execute "register vm #{guest[:id]} at chef server" do
    command %Q~knife client -u #{node[:fqdn]} -c /etc/chef/client.rb -k /etc/chef/client.pem create #{hostname} -f #{chef_archived_key}~
    action :run
    environment 'EDITOR' => 'echo'
    not_if "test -f #{chef_archived_key}"
  end

  execute "archive chef private key on #{guest[:id]}" do
    command %Q~cp #{chef_private_key} #{chef_archived_key}~
    action :run
    not_if "test -f #{chef_archived_key}"
    only_if "test -f #{chef_private_key}"
  end

  execute "restore chef private key on #{guest[:id]}" do
    command %Q~cp #{chef_archived_key} #{chef_private_key}~
    action :run
    only_if "test -f #{chef_archived_key}"
    not_if "test -f #{chef_private_key}"
  end

  execute "add rubygems executable directory to environment on #{guest[:id]}" do
    bad_bin = "/var/lib/gems/1.8/bin"
    not_if "grep ':#{bad_bin}' #{rootfs}/etc/environment"
    command %Q~sed -i.rubygems 's#"$#:#{bad_bin}"#' #{rootfs}/etc/environment~
  end

end

#init script which mount all btrfs subvol into /data/vms_data
template "/etc/init/mount-btrfs-vm.conf" do
  source 'upstart-mount-btrfs.erb'
  variables :mount_line => btrfs_mount_line
  action :create
end
if node["zabbix"]["agent"]["groups"]
  node.default["zabbix"]["agent"]["groups"] << "GroupA"
else
  node.default["zabbix"]["agent"]["groups"] = ["GroupB"]
end

