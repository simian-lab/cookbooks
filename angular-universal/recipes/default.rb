app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"
node_version = 'v6.2.2'

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe 'chef_nginx::http_v2_module'
include_recipe 'nvm'

nvm_install node_version do
  from_source false
  alias_as_default true
  action :create
end

template '/etc/nginx/sites-enabled/000-default' do
  source 'nginx.erb'
  variables({
    server_name: app['domains'].first,
    docroot: app_path
  })
end

execute "restart_nginx" do
  command "service nginx restart"
  user "root"
  action :run
end