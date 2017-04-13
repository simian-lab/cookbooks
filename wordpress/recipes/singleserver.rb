# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# 1. We install the dependencies
mysql_service 'wp' do
  port '3306'
  version '5.7'
  initial_root_password 'm0nk3ysl4b'
  action [:create, :start]
end

# TODO: Set up the backup procedures for both /uploads and the Database