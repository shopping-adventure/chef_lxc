Ohai.plugin(:Virtualisationlxc) do

  #require_plugin 'virtualization'

  def get_vlxc_values
    if File.exists?("/proc/1/cpuset")
      proc_cpuset = File.read("/proc/1/cpuset")
      if proc_cpuset.eql?("/\n") && File.directory?("/var/lib/lxc")
        virtualization[:system] = "linux-lxc"
        virtualization[:role] = "host"
      else
        if File.exist?("/proc/1/environ")
          proc_environ = File.read("/proc/1/environ")
          virtualization[:system] = "linux-lxc"
          virtualization[:role] = "guest"
        end
      end
    end
  end

  collect_data do
    get_vlxc_values
  end
end
