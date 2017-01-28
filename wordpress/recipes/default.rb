# Installing some required packages
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

  # We create the site
  web_app app['shortname'] do
    template 'web_app.conf.erb'
    server_name app['domains'].first
    server_aliases app['domains'].drop(1)
    docroot app_path
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

# We make sure the ENV vars are usable from the start
bash "update_env_vars" do
  user "root"
  code <<-EOS
  source /etc/environment
  EOS
end

# include_recipe 'php::default'
include_recipe 'php::module_mysql'
include_recipe 'apache2::mod_php'
#
# # Now we need to make sure php.ini can read the variables
# ruby_block "insert_env_vars" do
#   block do
#     file = Chef::Util::FileEdit.new('/etc/php/7.0/apache2/php.ini')
#     file.search_file_replace_line /^variables_order =/, "variables_order = \"GPCS\""
#   end
# end