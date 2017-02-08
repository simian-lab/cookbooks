app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe 'nvm::default'

nvm_install 'v6.2.2' do
  from_source false
  alias_as_default true
  action :create
end

execute 'install_angular' do
  command "npm install -g angular-cli"
  cwd app_path
end

execute 'install_dependencies' do
  command "npm install"
  cwd app_path
end

execute 'build_ng' do
  command "ng build --prod"
  cwd app_path
end