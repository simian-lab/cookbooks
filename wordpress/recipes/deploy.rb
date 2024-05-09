log 'debug' do
  message 'Simian-debug: Start deploy.rb'
  level :info
end

app = {
  'app_source' => {},
  'environment' => {}
}

app_path = "/srv/wordpress"

aws_ssm_parameter_store 'getAppSourceUrl' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_URL'
  return_key 'APP_SOURCE_URL'
  action :get
end

aws_ssm_parameter_store 'getAppSourceRevision' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_REVISION'
  return_key 'APP_SOURCE_REVISION'
  action :get
end

aws_ssm_parameter_store 'getAppSourceSshKey' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_SSH_KEY'
  return_key 'APP_SOURCE_SSH_KEY'
  action :get
end

ruby_block "define-app" do
  block do
    app = {
      'app_source' => {
        'url' => node.run_state['APP_SOURCE_URL'],
        'revision' => node.run_state['APP_SOURCE_REVISION'],
        'ssh_key' => node.run_state['APP_SOURCE_SSH_KEY']
      },
      'environment' => {}
    }
  end
end

ruby_block 'log_app' do
  block do
    Chef::Log.info("El valor de app es: #{app}")
  end
  action :run
end

execute 'Add an exception for this directory' do
  command "git config --global --add safe.directory #{app_path}"
  user "root"
end

execute 'eval de ssh agent' do
  command "eval $(ssh-agent -s) && ssh-add /home/#{node['user']}.ssh/id_rsa"
  user "root"
  action :run
end

execute 'ssh-add -l' do
  command "ssh-add -l"
  user "root"
  action :run
end

application app_path do
  environment.update(app['environment'])

  git app_path do
    repository 'git@bitbucket.org:externado/website.git'
    revision 'staging'
  end
end

# make sure permissions are correct
execute "chown-data-www" do
  command "chown -R www-data:www-data #{app_path}"
  user "root"
  action :run
  not_if "stat -c %U #{app_path} | grep www-data"
end

# Clean cache
service 'varnish' do
  action [:restart]
end

# and now, W3TC's cloudfront config
cloudfront_config = ""

if app['environment']['CLOUDFRONT_DISTRIBUTION']
  cloudfront_config = app['environment']['CLOUDFRONT_DISTRIBUTION']

  ruby_block 'cloudfront_edit' do
    block do
      w3config = Chef::Util::FileEdit.new("#{app_path}/wp-content/w3tc-config/master.php")
      w3config.search_file_replace_line("cdn.cf2.id", "\"cdn.cf2.id\": \"#{cloudfront_config}\",")
      w3config.write_file
    end
  end
end

log 'debug' do
  message 'Simian-debug: End deploy.rb'
  level :info
end
