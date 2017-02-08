app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe "nodejs::default"

nodejs_npm "angular-cli" do
  json true
  options ['-g']
end