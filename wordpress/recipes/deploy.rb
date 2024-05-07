aws_ssm_parameter_store 'getAppSourceUrl' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_URL'
  return_key 'app_source_url'
  action :get
end

ruby_block 'log_parameter_values' do
  block do
    Chef::Log.info("El valor de app source es: #{node.run_state['app_source_url']}")
  end
  action :run
end

aws_ssm_parameter_store 'getAppSourceRevision' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_REVISION'
  return_key 'app_source_revision'
  action :get
end

aws_ssm_parameter_store 'getAppSourceSsh_Key' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/APP_SOURCE_SSH_KEY'
  return_key 'app_source_ssh_key'
  action :get
end

app = {
  'app_source' => {
    'url' => node.run_state['app_source_url'],
    'revision' => node.run_state['app_source_revision'],
    'ssh_key' => node.run_state['app_source_ssh_key']
  },
  'environment' => {}
}

log 'Current recipe' do
  message 'Running the deploy recipe for WordPress.'
  level :info
end

aws_ssm_parameter_store 'getShortName' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/SHORT_NAME'
  return_key 'short_name'
  action :get
end


execute 'Add an exception for this directory' do
  command lazy {"git config --global --add safe.directory /srv/#{node.run_state['short_name']}"}
  user "root"
end

app_path = "/srv/wordpress"

application app_path do
  environment.update(app['environment'])

  git app_path do
    repository 'git@bitbucket.org:externado/website.git'
    revision 'staging'
    deploy_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDtpce4iRwSOTGkfG3UZUbwepLAwfaS9nQduVWsxiiqtZANS3ejpAS4KVxq0YMMBg20LKcfkdL+BuRs5RlVVsCCFCMekpgzQAdm6LM3q5Z7H320nyRBjkAiYic74dI4GvcAqWnUuk5QI6bG/CxnhlAxF2ELELaXXcIyxdFUWypfY6sT/XsUorg4o/76bUk3cAY2Vo5Wmd9xRkVP0A2Rs3FAvwVbrc7DYxhW4M5AmtnA7WWHZwF52dX7FIzyICkQCeiux2nokcRrjUlaGFA5qlBRQHK5S02Wb2izAr64l03dc/PPwTX7RMZ9qDb6mvwxdvi0FA9VagWRFbQrrjUTzX2N ivan@Ivans-MacBook-Pro.local'
  end
end

#make sure permissions are correct
execute "chown-data-www" do
  command "chown -R www-data:www-data /srv/#{node.run_state['short_name']}"
  user "root"
  action :run
  not_if "stat -c %U /srv/#{node.run_state['short_name']} | grep www-data"
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
