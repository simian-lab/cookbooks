app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe "nodejs::default"
include_recipe "nodejs::npm"

nodejs_npm "angular-cli" do
  options ['-g']
end