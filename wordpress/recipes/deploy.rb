log 'debug' do
  message 'Simian-debug: Start deploy.rb'
  level :info
end

app = {
  'app_source' => {},
  'environment' => {},
  'shortname' => {}
}

app_path = ''

aws_ssm_parameter_store 'getShortName' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/SHORT_NAME'
  return_key 'SHORT_NAME'
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
      'environment' => {},
      'shortname' => node.run_state['SHORT_NAME']
    }

    app_path = "/srv/#{app['shortname']}"
  end
end

execute 'Add an exception for this directory' do
  command lazy {"git config --global --add safe.directory #{app_path}"}
  user "root"
end

application app_path do
  environment.update(app['environment'])

  git app_path do
    repository app['app_source']['url']
    revision app['app_source']['revision']
    deploy_key app['app_source']['ssh_key']
  end
end

# make sure permissions are correct
execute "chown-data-www" do
  command lazy {"chown -R www-data:www-data #{app_path}"}
  user "root"
  action :run
  not_if lazy {"stat -c %U #{app_path} | grep www-data"}
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
