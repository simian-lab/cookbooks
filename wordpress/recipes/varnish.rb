include_recipe 'varnish::default'

package 'varnish'

service 'varnish' do
  action [:enable, :start]
end

varnish_config 'default' do
  listen_address '0.0.0.0'
  listen_port 80
end

vcl_template 'default.vcl' do
  action :configure
end

# varnishlog
varnish_log 'default'

# varnishncsa
varnish_log 'default_ncsa' do
  log_format 'varnishncsa'
end