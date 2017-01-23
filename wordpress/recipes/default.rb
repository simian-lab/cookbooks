include_recipe 'apt::default'

app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

application app_path do
  environment.update(app['environment'])

  git app_path do
    repository app['app_source']['url']
    revision app['app_source']['revision']
    deploy_key app['app_source']['ssh_key']
  end

  web_app app['shortname'] do
    template 'web_app.conf.erb'
    server_name app['domains'].first
    server_aliases app['domains'].drop(1)
    docroot app_path
  end
end

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

include_recipe 'apache2::mod_php5'