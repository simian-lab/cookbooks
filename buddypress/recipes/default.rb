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

require 'aws-sdk-ec2'

log 'debug' do
  message 'Simian-debug: Start default.rb'
  level :info
end

current_instance_id = node['ec2']['instance_id']
ec2_client = Aws::EC2::Client.new(region: 'us-west-2')
response = ec2_client.describe_instances(instance_ids: [current_instance_id])

response = ec2_client.describe_tags(filters: [
  { name: 'resource-id', values: [current_instance_id] }
])

component_name = nil

response.tags.each do |tag|
  if tag.key === 'aws:cloudformation:stack-name'
    component_name = tag.value
  end
end

app = {
  'environment' => {}
}

app_path = "/srv/wordpress"

aws_ssm_parameter_store 'getAwsSmtpUsr' do
  path "/ApplyChefRecipes-Preset/#{component_name}/AWS_SMTP_USR"
  return_key 'AWS_SMTP_USR'
  action :get
end

aws_ssm_parameter_store 'getAwsSmtpPsw' do
  path "/ApplyChefRecipes-Preset/#{component_name}/AWS_SMTP_PSW"
  return_key 'AWS_SMTP_PSW'
  action :get
end

aws_ssm_parameter_store 'getDBHost' do
  path "/ApplyChefRecipes-Preset/#{component_name}/DB_HOST"
  return_key 'DB_HOST'
  action :get
end

if (component_name === 'beta-comunidad-virtual-Wordpress-App-47f171')
  aws_ssm_parameter_store 'getDBReplicas' do
    path "/ApplyChefRecipes-Preset/#{component_name}/DB_REPLICAS"
    return_key 'DB_REPLICAS'
    action :get
  end
end

aws_ssm_parameter_store 'getDBName' do
  path "/ApplyChefRecipes-Preset/#{component_name}/DB_NAME"
  return_key 'DB_NAME'
  action :get
end

aws_ssm_parameter_store 'getDBPassword' do
  path "/ApplyChefRecipes-Preset/#{component_name}/DB_PASSWORD"
  return_key 'DB_PASSWORD'
  action :get
end

aws_ssm_parameter_store 'getDBUser' do
  path "/ApplyChefRecipes-Preset/#{component_name}/DB_USER"
  return_key 'DB_USER'
  action :get
end

aws_ssm_parameter_store 'getPhpImagickEnable' do
  path "/ApplyChefRecipes-Preset/#{component_name}/PHP_IMAGICK_ENABLE"
  return_key 'PHP_IMAGICK_ENABLE'
  action :get
end

aws_ssm_parameter_store 'getPhpMbstringEnable' do
  path "/ApplyChefRecipes-Preset/#{component_name}/PHP_MBSTRING_ENABLE"
  return_key 'PHP_MBSTRING_ENABLE'
  action :get
end

aws_ssm_parameter_store 'getPhpZipEnable' do
  path "/ApplyChefRecipes-Preset/#{component_name}/PHP_ZIP_ENABLE"
  return_key 'PHP_ZIP_ENABLE'
  action :get
end

aws_ssm_parameter_store 'getRSAPrivateKey' do
  path "/ApplyChefRecipes-Preset/#{component_name}/RSA_PRIVATE_KEY"
  return_key 'RSA_PRIVATE_KEY'
  action :get
end

aws_ssm_parameter_store 'getRSAPublicKey' do
  path "/ApplyChefRecipes-Preset/#{component_name}/RSA_PUBLIC_KEY"
  return_key 'RSA_PUBLIC_KEY'
  action :get
end

aws_ssm_parameter_store 'getSiteUrl' do
  path "/ApplyChefRecipes-Preset/#{component_name}/SITE_URL"
  return_key 'SITE_URL'
  action :get
end

aws_ssm_parameter_store 'getSSLEnable' do
  path "/ApplyChefRecipes-Preset/#{component_name}/SSL_ENABLE"
  return_key 'SSL_ENABLE'
  action :get
end

ruby_block "define-app" do
  block do
    app = {
      'environment' => {
        'AWS_SMTP_USR' => node.run_state['AWS_SMTP_USR'],
        'AWS_SMTP_PSW' => node.run_state['AWS_SMTP_PSW'],
        'DB_HOST' => node.run_state['DB_HOST'],
        'DB_REPLICAS' => node.run_state['DB_REPLICAS'],
        'DB_NAME' => node.run_state['DB_NAME'],
        'DB_PASSWORD' => node.run_state['DB_PASSWORD'],
        'DB_USER' => node.run_state['DB_USER'],
        'PHP_IMAGICK_ENABLE' => node.run_state['PHP_IMAGICK_ENABLE'],
        'PHP_MBSTRING_ENABLE' => node.run_state['PHP_MBSTRING_ENABLE'],
        'PHP_ZIP_ENABLE' => node.run_state['PHP_ZIP_ENABLE'],
        'SITE_URL' => node.run_state['SITE_URL'],
        'SSL_ENABLE' => node.run_state['SSL_ENABLE']
      }
    }
  end
end

ruby_block 'log_app' do
  block do
    Chef::Log.info("El valor de app es: #{app}")
  end
  action :run
end

# 1. Installing some required packages
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

# Install php
log 'debug' do
  message 'Simian-debug: Install PHP'
  level :info
end

package 'Install PHP' do
  package_name 'php7.2'
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

# Optionally Install php-ssh2 dependency
if app['environment']['PHP_SSH_ENABLE']
  package 'Install PHP ssh' do
    package_name 'php-ssh2'
  end
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
#if node['php']['version']=='7.0.4'
#  php_ver = '7.0'
#else
#  php_ver = node['php']['version']
#end

php_ver = '7.2'

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

domains = ''
is_multisite = 'no'

if (component_name === 'beta-externado-WordPress-4eddee')
  domains = 'beta.uexternado.edu.co'
end

if(component_name === 'Davidaclub-Prod-Davidaclub-Prod-a386d3')
  domains = 'davidaclub.com'
end

if (component_name === 'beta-comunidad-virtual-Wordpress-App-47f171')
  domains = 'beta-comunidadvirtual.uexternado.edu.co'
end

if (component_name === 'prod-comunidad-virtual-Wordpress-App-fc620f')
  domains = 'comunidadvirtual.uexternado.edu.co'
end

domains_array = domains.split(',')

# 4. We create the site
web_app 'wordpress' do
  template 'web_app.conf.erb'
  allow_override 'All'
  server_name domains_array.first
  server_port 80
  server_aliases domains_array.drop(1)
  docroot app_path
  multisite is_multisite
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
  command "wget -q -O - #{domains_array.first}/wp-cron.php?doing_wp_cron"
end

#7
execute "mkdir ~/.ssh/" do
  command "mkdir ~/.ssh/"
  action :run
end

file "/root/.ssh/id_rsa" do
  content lazy {node.run_state['RSA_PRIVATE_KEY']}
end

execute "change permissions to key" do
  command "chmod 600 /root/.ssh/id_rsa"
  action :run
end

file "/root/.ssh/id_rsa.pub" do
  content lazy {node.run_state['RSA_PUBLIC_KEY']}
end

execute "change permissions to key" do
  command "chmod 644 /root/.ssh/id_rsa.pub"
  action :run
end

execute "known hosts" do
  command "ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts"
  action :run
end

log 'debug' do
  message 'Simian-debug: End default.rb'
  level :info
end
