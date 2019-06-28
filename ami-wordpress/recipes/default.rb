# This recipe configures the base environment needed for a WordPress site.
# In summary, it:
#
# 1. Uses the "SimianDefaultUbuntu" AMI wich contains:
#     - Apache2 (v 2.4)
#     - PHP (v7)
#     - PHP-(curl,mbstring,mysql,xml,gd,ssh2,zip,memcached,imagick,mbstring)
#     - Varnish (v4)
#     - Sendmail
#     - nfs-common
#     - htop
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
# b) It has only been tested with Ubuntu 16.04 LTS It *should* work with other
#    operating systems, but it probably would take some additional work.
#
# — Sebastian Giraldo (sebastian@simian.co) / Jun 28, 2019


# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# Include recipes
include_recipe 'varnish::default'

# Set the environment variables for PHP
ruby_block "insert_apache_env_vars" do
  block do
    file = Chef::Util::FileEdit.new('/etc/apache2/envvars')
    app['environment'].each do |key, value|
      Chef::Log.info("Setting apache envvar #{key}= #{key}=\"#{value}\"")
      file.insert_line_if_no_match /^export #{key}\=/, "export #{key}=\"#{value}\""
      file.write_file
    end
  end
end

# test debug this part
execute "start_virtualhost" do
  command "sudo cp /etc/apache2/envvars /tmp/"
  user "root"
  action :run
end

# Make sure PHP can read the vars
ruby_block "php_env_vars" do
  block do
    file = Chef::Util::FileEdit.new('/etc/php/7.0/apache2/php.ini')
    Chef::Log.info("Setting the variable order for PHP")
    file.search_file_replace_line /^variables_order =/, "variables_order = \"EGPCS\""
    file.write_file
  end
end

# map the environment_variables node to ENV variables
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

# We create the site
web_app app['shortname'] do
  template 'web_app.conf.erb'
  allow_override 'All'
  server_name app['domains'].first
  server_port 8080
  server_aliases app['domains'].drop(1)
  docroot app_path
  multisite app['environment']['MULTISITE']
end

# Register and Start virtualhost
execute "start_virtualhost" do
  command "sudo a2ensite #{app['shortname']}"
  user "root"
  action :run
end

# Reload apache
service 'apache2' do
  action [:reload, :restart]
end

# We configure caching

# first off, Varnish (with custom error page if present)
error_page = ""

if app['environment']['VARNISH_ERROR_PAGE']
  error_page = "/srv/#{app['shortname']}/#{app['environment']['VARNISH_ERROR_PAGE']}"
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

template '/etc/varnish/default.vcl' do
  source 'default.vcl.erb'
  variables({
    errorpage: error_page,
    cors: cors,
    browser_cache: browser_cache,
    force_ssl_dns: force_ssl_dns
  })
end

varnish_config 'default' do
  listen_address '0.0.0.0'
  listen_port 80
end

varnish_log 'default'

varnish_log 'default_ncsa' do
  log_format 'varnishncsa'
end

service 'varnish' do
  action [:restart]
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

# Call the WordPress cron
cron 'wpcron' do
  minute '*'
  command "wget -q -O - #{app['domains'].first}/wp-cron.php?doing_wp_cron"
end