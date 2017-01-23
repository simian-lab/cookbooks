include_recipe 'apt::default'

app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# We install the app according to the config info
application app_path do
  environment.update(app['environment'])

  git app_path do
    repository app['app_source']['url']
    revision app['app_source']['revision']
    deploy_key app['app_source']['ssh_key']
  end
end

# We install nginx
include_recipe 'nginx'

# Installing some required packages
package "php5-mysql" do
  action :install
end

package "php-apc" do
  action :install
end

package "php5-curl" do
  action :install
  notifies :reload, 'service[php5-fpm]'
end