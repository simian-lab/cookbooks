# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'
include_recipe 'chef_nginx::http_v2_module'
include_recipe 'chef_nginx::http_ssl_module'