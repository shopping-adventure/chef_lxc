# This creates a network bridge
#
# Warning: Hetzner does not support bridged interfaces, 
# so do not try to add the main interface to the bridge


package 'bridge-utils'

file '/etc/sysctl.d/33-ip-forward.conf' do
  backup false
  action :create
  content <<-EOSYS
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.all.proxy_ndp=1
  EOSYS
end

bash "deactivate lxc default bridge" do
  # is the interfaces newer
  code <<-EOSH
          sed -e s/"USE_LXC_BRIDGE=\"true\"/USE_LXC_BRIDGE=\"fasle\""/g -i /etc/default/lxc-net  
          sed -e s/"USE_LXC_BRIDGE=\"true\"/USE_LXC_BRIDGE=\"fasle\""/g -i /etc/default/lxc
  EOSH
end

#end
