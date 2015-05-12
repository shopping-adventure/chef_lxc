# Drop by Chef recipe LXC
# Custom cloud for VM on LXC or on EC2

Ohai.plugin(:Customcloud) do
  provides 'customcloud'
  depends "ec2"
  #require_plugin 'cloud'
  def create_objects
    cloud Mash.new
    cloud[:public_ips] = Array.new
    cloud[:private_ips] = Array.new
  end
  # ----------------------------------------
  # ec2
  # ----------------------------------------

  # Is current cloud ec2?
  #
  # === Return
  # true:: If ec2 Hash is defined
  # false:: Otherwise
  def on_ec2?
    ec2 != nil
  end

  # Fill cloud hash with ec2 values
  def get_ec2_values
    cloud[:public_ips] << ec2['public_ipv4']
    cloud[:private_ips] << ec2['local_ipv4']
    cloud[:public_ipv4] = ec2['public_ipv4']
    cloud[:public_hostname] = ec2['public_hostname']
    cloud[:local_ipv4] = ec2['local_ipv4']
    cloud[:local_hostname] = ec2['local_hostname']
    cloud[:provider] = "ec2"
  end

  # ----------------------------------------
  # LXC
  # ----------------------------------------
  # Is current cloud lxc-based?
  #
  # === Return
  # true:: If LXC Hash is defined
  # false:: Otherwise
  def on_lxc?
    lxc != nil
  end


  def get_lxc_values
    #pub_ipv4 = `ip addr show dev public|grep -v vrrp`[/inet [^ ,\/]*/][/[\d,\.].*/]
    pub_ipv4 = `ip addr show dev public|grep -v vrrp` =~ /inet ([0-9.]*)/ && $1
    pub_ipv6 = `ip addr show dev public|grep -v fe80` =~ /inet6 ([a-f,0-9:]*)/ && $1
    priv_ipv6 = `ip addr show dev private|grep -v fe80` =~ /inet6 ([a-f,0-9:]*)/ && $1
    #priv_ipv4 = `ip addr show dev private|grep -v vrrp`[/inet [^ ,\/]*/][/[\d,\.].*/]
    priv_ipv4 = `ip addr show dev private|grep -v vrrp` =~ /inet ([0-9.]*)/ && $1
    vrrp_pub_ipv6 = `ip addr show dev public|grep vrrpa`
    vrrp_priv_ipv6 = `ip addr show dev private|grep vrrpa`
    vrrp_priv_ipv4 = `ip addr show dev private|grep vrrp`
    vrrp_pub_ipv4 = `ip addr show dev public|grep vrrp`
    privhost = `hostname`.strip
    privhost[/\./]=".priv."
    cloud[:public_ips] = [pub_ipv4]
    cloud[:private_ips] = [priv_ipv4]
    cloud[:public_ipv4] = pub_ipv4
    unless pub_ipv6.nil?
      cloud[:public_ipv6] = pub_ipv6
    end
    unless priv_ipv6.nil?
      cloud[:local_ipv6] = priv_ipv6
    end
    unless vrrp_priv_ipv6.empty?
      vrrp_priv_ipv6 = `ip addr show dev private|grep vrrpa` =~ /inet6 ([a-f,0-9:]*)/ && $1
      cloud[:local_vrrp_ipv6] = vrrp_priv_ipv6
    end
    unless vrrp_pub_ipv6.empty?
      vrrp_pub_ipv6 = `ip addr show dev public|grep vrrpa` =~ /inet6 ([a-f,0-9:]*)/ && $1
      cloud[:public_vrrp_ipv6] = vrrp_pub_ipv6
    end
    unless vrrp_priv_ipv4.empty?
      vrrp_priv_ipv4 = `ip addr show dev private|grep vrrp`[/inet [^ ,\/]*/][/[\d,\.].*/]
      cloud[:local_vrrp_ipv4] = vrrp_priv_ipv4
    end
    unless vrrp_pub_ipv4.empty?
      vrrp_pub_ipv4 = `ip addr show dev public|grep vrrp`[/inet [^ ,\/]*/][/[\d,\.].*/]
      cloud[:public_vrrp_ipv4] = vrrp_pub_ipv4
    end
    cloud[:public_hostname] = `hostname`.strip
    cloud[:public_hostname] = `hostname`.strip
    cloud[:local_ipv4] = priv_ipv4
    cloud[:local_hostname] = privhost
    cloud[:provider] = "chef-lxc"
  end

  collect_data do
    if on_ec2?
      create_objects
      get_ec2_values
    else
      # setup LXC cloud forced
      create_objects
      get_lxc_values
    end
  end
end
