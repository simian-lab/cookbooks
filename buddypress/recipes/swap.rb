total_ram_mb      = node['memory']['total'].gsub('kB', '').to_i / 1024
available_disk_mb = node['filesystem']['/']['kb_available'].to_i / 1024
disk_budget_mb    = [available_disk_mb - 2048, 0].max

swap_size_mb = [total_ram_mb * 2, 4096, disk_budget_mb].min

execute 'create swap file' do
  command "fallocate -l #{swap_size_mb}m /swapfile"
  not_if { ::File.exist?('/swapfile') }
end

execute 'set swap permissions' do
  command 'chmod 600 /swapfile'
  only_if { ::File.exist?('/swapfile') }
end

execute 'format swap' do
  command 'mkswap /swapfile'
  only_if { ::File.exist?('/swapfile') }
  not_if 'swapon --show | grep -q /swapfile'
end

execute 'enable swap' do
  command 'swapon /swapfile'
  only_if { ::File.exist?('/swapfile') }
  not_if 'swapon --show | grep -q /swapfile'
end

mount 'swap' do
  device   '/swapfile'
  fstype   'swap'
  options  'sw'
  dump     0
  pass     0
  action   [:enable]
end
