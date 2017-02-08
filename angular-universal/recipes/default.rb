app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

node_version = 'v6.2.2'

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe 'nvm::default'

nvm_install node_version do
  from_source false
  alias_as_default true
  action :create
end

nvm_alias_default node_version do
  action :create
end

execute 'install_angular' do
  command "npm install -g angular-cli"
  user 'nginx'
end