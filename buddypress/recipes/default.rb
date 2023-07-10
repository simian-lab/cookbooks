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


# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# 1. Installing some required packages
include_recipe 'apt::default'

include_recipe 'apache2::mod_php'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_expires'
include_recipe 'apache2::mod_ext_filter'

# Install php

package 'Install PHP' do
  package_name 'php7.4'
end

package 'Install PHP libapache' do
  package_name 'libapache2-mod-php7.4'
end

package 'Install PHP cURL' do
  package_name 'php7.4-curl'
end

package 'Install PHP mbstring' do
  package_name 'php7.4-mbstring'
end

package 'Install PHP mysql' do
  package_name 'php7.4-mysql'
end

package 'Install PHP xml' do
  package_name 'php7.4-xml'
end

package 'Install PHP gd' do
  package_name 'php7.4-gd'
end

package 'Memcached' do
  package_name 'php7.4-memcached'
end

package 'Install PHP imagick' do
  package_name 'php7.4-imagick'
end

package 'Install PHP Mail' do
  package_name 'php7.4-mail'
end

package 'htop' do
  package_name 'htop'
end

# Optionally Install php-ssh2 dependency
package 'Install PHP ssh' do
  package_name 'php7.4-ssh2'
end

# Optionally Install php-zip dependency
package 'Install PHP zip' do
  package_name 'php7.4-zip'
end


# 2. Set the environment variables for PHP
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

# Make sure PHP can read the vars
if node['php']['version']=='7.0.4'
  php_ver = '7.0'
else
  php_ver = node['php']['version']
end
ruby_block "php_env_vars" do
  block do
    file = Chef::Util::FileEdit.new("/etc/php/#{php_ver}/apache2/php.ini")
    Chef::Log.info("Setting the variable order for PHP")
    file.search_file_replace_line /^variables_order =/, "variables_order = \"EGPCS\""
    file.write_file
  end
end

# 3. map the environment_variables node to ENV variables
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

# 4. We create the site
web_app app['shortname'] do
  template 'web_app.conf.erb'
  allow_override 'All'
  server_name app['domains'].first
  server_port 80
  server_aliases app['domains'].drop(1)
  docroot app_path
  multisite app['environment']['MULTISITE']
end

# 5. Last steps

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
