# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

include_recipe 'apt::default'
include_recipe 'chef_nginx::default'