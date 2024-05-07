# This recipe installs the base environment needed for a WordPress site.
# In summary, it:
#
# 1. Installs the minimum required packages, which are:
#     - Apache2 (v 2.4)
#     - PHP (v7)
#     - PHP's MySQL connector
#     - PHP GD for image manipulation
#     - Varnish (v4)
#
# 2. Makes sure the variables defined in the OpsWorks console are readable
#    in PHP.
#
# 3. Sets those same variables as ENV variables so we can use them on scripts
#    and other tasks.
#
# 4. Creates the Apache VirtualHost for the site. It uses the default template
#    which can be found in the `apache2` cookbook in this repo.
#
# 5. Configures caching with Varnish and W3TC.
#
# This is all it does. Other considerations (such as giving it EFS support
# for multi-server setups or installing a MySQL/MariaDB server for single
# server setups) should be done in other recipes.
#
# The actual deployment of the application code is done in the `deploy` recipe,
# since we don't need to build the entire environment with each deploy.
#
# There are some considerations that should be taken into account with this
# recipe:
#
# a) It is intended solely for Opsworks, not for local installations.
# b) It has only been tested with Ubuntu 16.04 LTS. It *should* work with other
#    operating systems, but it probably would take some additional work.
#
# — Ivan Vásquez (ivan@simian.co) / Jan 29, 2017

# Initial setup: just a couple vars we need

log 'debug' do
  message 'Simian-debug: Start default.rb'
  level :info
end

# Installing some required packages
include_recipe 'apt::default'

execute "latest-php" do
  command "sudo add-apt-repository ppa:ondrej/php -y"
  user "root"
  action :run
end

include_recipe 'apache2::mod_php'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_expires'
include_recipe 'apache2::mod_ext_filter'

package 'Install PHP' do
  package_name 'php7.2'
end

log 'debug' do
  message 'Simian-debug: Install PHP libapache'
  level :info
end

package 'Install PHP libapache' do
  package_name 'libapache2-mod-php7.2'
end

package 'Install PHP cURL' do
  package_name 'php7.2-curl'
end

package 'Install PHP mbstring' do
  package_name 'php7.2-mbstring'
end

package 'Install PHP mysql' do
  package_name 'php7.2-mysql'
end

package 'Install PHP xml' do
  package_name 'php7.2-xml'
end

package 'Install PHP gd' do
  package_name 'php7.2-gd'
end

package 'Memcached' do
  package_name 'php7.2-memcached'
end

package 'Install PHP imagick' do
  package_name 'php7.2-imagick'
end

package 'Install PHP Mail' do
  package_name 'php7.2-mail'
end

package 'Install PHP zip' do
  package_name 'php7.2-zip'
end

package 'Install PHP BCmath extension' do
  package_name 'php7.2-bcmath'
end

package 'varnish' do
  package_name 'varnish'
end

package 'htop' do
  package_name 'htop'
end

package 'Install PHP ssh' do
  package_name 'php-ssh2'
end

aws_ssm_parameter_store 'getDBHost' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/Deploy/DB_HOST'
  return_key 'db_host'
  action :get
end

aws_ssm_parameter_store 'getVarnishErrorPage' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/VARNISH_ERROR_PAGE'
  return_key 'varnish_error_page'
  action :get
end

aws_ssm_parameter_store 'getDomains' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/DOMAINS'
  return_key 'domains'
  action :get
end

aws_ssm_parameter_store 'getMultisite' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/MULTISITE'
  return_key 'multisite'
  action :get
end

ruby_block "define_app" do
  block do
    app = {
      'domains' => [node.run_state['domains']],
      'environment' => {
        'DB_HOST' => node.run_state['db_host'],
        'MULTISITE' => node.run_state['multisite']
      }
    }
  end
end

#2. Set the environment variables for PHP
ruby_block "insert_env_vars" do
  block do
    file = Chef::Util::FileEdit.new('/etc/apache2/envvars')
    app['environment'].each do |key, value|
      Chef::Log.info("Setting apache envvar #{key}= #{key}=\"#{value}\"")
      file.insert_line_if_no_match /^export #{key}\=/, "export #{key}=\"#{value}\""
      file.write_file
    end
  end
end

#Make sure PHP can read the vars
if node['php']['version']=='7.0.4'
  php_ver = '7.0'
else
  php_ver = node['php']['version']
end

php_ver = '7.2'

ruby_block "php_env_vars" do
  block do
    file = Chef::Util::FileEdit.new("/etc/php/#{php_ver}/apache2/php.ini")
    Chef::Log.info("Setting the variable order for PHP")
    file.search_file_replace_line /^variables_order =/, "variables_order = \"EGPCS\""
    file.write_file
  end
end

#3. map the environment_variables node to ENV variables
ruby_block "insert_env_vars" do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    app['environment'].each do |key, value|
      Chef::Log.info("Setting ENV variable #{key}= #{key}=\"#{value}\"")
      file.insert_line_if_no_match /^#{key}\=/, "#{key}=\"#{value}\""
      file.write_file
    end
  end
end

# source the file so we can use it right away if needed
bash "update_env_vars" do
  user "root"
  code <<-EOS
  source /etc/environment
  EOS
end

aws_ssm_parameter_store 'getShortName' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/SHORT_NAME'
  return_key 'short_name'
  action :get
end

app['short_name'] = node.run_state['short_name'];
app_path = "/srv/wordpress"

# 4. We create the site
web_app app['short_name'] do
  template 'web_app.conf.erb'
  allow_override 'All'
  server_name app['domains'].first
  server_port 8080
  server_aliases app['domains'].drop(1)
  docroot app_path
  multisite app['environment']['MULTISITE']
end

# 5. We configure caching

# first off, Varnish (with custom error page if present)
error_page = ""

if app['environment']['VARNISH_ERROR_PAGE']
  error_page = "/srv/#{app['short_name']}/#{app['environment']['VARNISH_ERROR_PAGE']}"
end

# define a CORS header
cors = ""

if app['environment']['CORS']
  cors = "#{app['environment']['CORS']}"
end

# Add a long max-age header if present
browser_cache = ""

if app['environment']['LONG_BROWSER_CACHE']
  browser_cache = "#{app['environment']['LONG_BROWSER_CACHE']}"
end

# Add a force SSL redirection if present
force_ssl_dns = ""

if app['environment']['FORCE_SSL_DNS']
  force_ssl_dns = "#{app['environment']['FORCE_SSL_DNS']}"
end

# Add url exclusions if exists
url_exclusions = ""

if app['environment']['VARNISH_URL_EXCLUSIONS']
  string_url_exclusions = "#{app['environment']['VARNISH_URL_EXCLUSIONS']}"
  url_exclusions = string_url_exclusions.split(",")
end

# Add host exclusions if exists
host_exclusions = ""

if app['environment']['VARNISH_HOST_EXCLUSIONS']
  string_host_exclusions = "#{app['environment']['VARNISH_HOST_EXCLUSIONS']}"
  host_exclusions = string_host_exclusions.split(",")
end

service 'varnish' do
  supports [:restart, :start, :stop]
  action [:nothing]
end

template '/etc/varnish/default.vcl' do
  source 'default.vcl.erb'
  variables({
    errorpage: error_page,
    cors: cors,
    browser_cache: browser_cache,
    url_exclusions: url_exclusions,
    host_exclusions: host_exclusions,
    force_ssl_dns: force_ssl_dns
  })
end

template '/etc/systemd/system/varnish.service' do
  source 'varnish.service.erb'
end

template '/etc/systemd/system/varnishlog.service' do
  source 'varnishlog.service.erb'
end

template '/etc/systemd/system/varnishncsa.service' do
  source 'varnishncsa.service.erb'
end

template '/etc/default/varnish' do
  source 'varnish.erb'
  notifies :restart, 'service[varnish]', :delayed
end

execute "disable varnish log" do
  command "ln -sf /dev/null /var/log/varnish/varnish.log"
  user "root"
  action :run
end

execute "disable varnishncsa log" do
  command "ln -sf /dev/null /var/log/varnish/varnishncsa.log"
  user "root"
  action :run
end

execute 'systemctl-daemon-reload' do
  command '/bin/systemctl --system daemon-reload'
  user "root"
  action :run
end

# 6. Call the WordPress cron
cron 'wpcron' do
  minute '*'
  command "wget -q -O - #{app['domains'].first}/wp-cron.php?doing_wp_cron"
end

log 'debug' do
  message 'Simian-debug: End default.rb'
  level :info
end
