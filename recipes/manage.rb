include_recipe 'lxc::cgroup'

package 'lxc'

#deactivate lxc default bridge, we use our own bridge
execute "deactivate init lxc-net bridge" do
  command %Q~sed -e 's/env USE_LXC_BRIDGE="true"/env USE_LXC_BRIDGE="false"/g' -i /etc/init/lxc-net.conf~
  not_if 'grep USE_LXC_BRIDGE="false" /etc/init/lxc-net.conf'
end

execute "deactivate default lxc-net bridge" do
  command %Q~sed -e 's/USE_LXC_BRIDGE="true"/USE_LXC_BRIDGE="false"/g' -i /etc/default/lxc-net~
  not_if 'grep USE_LXC_BRIDGE="false" /etc/default/lxc-net'
end
