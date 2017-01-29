# Installing some required packages
include_recipe 'apt::default'
include_recipe 'php::default'
include_recipe 'php::module_mysql'
include_recipe 'apache2::mod_php'

app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# Set the environment variables for PHP
ruby_block "insert_env_vars" do
  block do
    file = Chef::Util::FileEdit.new('/etc/apache2/envvars')
    app['environment'].each do |key, value|
      Chef::Log.info("Setting ENV variable #{key}= #{key}=\"#{value}\"")
      file.insert_line_if_no_match /^export #{key}\=/, "export #{key}=\"#{value}\""
      file.write_file
    end
  end
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

# We create the site
web_app app['shortname'] do
  template 'web_app.conf.erb'
  allow_override 'All'
  server_name app['domains'].first
  server_aliases app['domains'].drop(1)
  docroot app_path
end