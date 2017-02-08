app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

node_version = 'v6.2.2'

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe "nodejs::nodejs_from_source"

nodejs_npm "angular-cli" do
  json true
  options ['-g']
end