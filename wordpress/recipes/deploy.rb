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
    deploy_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1M8DDi/Jh8OWPTvK1NHnvbj8cSTV/vcmN8ktiac0qH9aafLVsmPKk/a8iXxgH3ReIQd18RMcIflE35CXikw66Kvq2abt5zcvBninEklg51Fr7fZEVgPHgdvfmDgmxwhpSVzQ8iGoKmxbiF7FiA56bx+2Sfoj0Vahxaw0cxeQV3Mvs1itzWlVlryASNkSk7vi8LbCVW5pa6NEaDnYXaH7fJPXCU5DRhlLa9furhihT9T63E5+EhMV/VHATy/YrZ7DfSVWUYoN12rAX9d9LHGpBPrqb6lD5WAmh3ZUkWwX0snoHP3Ui0tjYBxdimgNJOiyw3qlaZzxJ8g0RECT2q1+ck9hQ+Qqq69/4TSvBODQddUbAjsvgRaCdKE5eyfEnF9ZVf/Z4bacnhU2GTV63ifES6W6LkNCOMlQ/K3kZECkcnGloQa9hE9zPIodQMo0mOIvYJa7nXhw3t0oipzxKFSMFq8Zkx6Oj3Qh9cz8ELdKvvENUEw9JBFlOfK3pis/31MijYXJmV7j8NYK0qWU3OlWrBN/6L0mYgHO+jNGbyURatpVs+kUqS6yXKsIkvj/bO0NHviav1+ebowD4UGOfKTm3LuT7P5UKrkrVVeS2/S/4EAKtnV9f4YPelbUH24IZH2PrUegSpnkodz2Zi39uQ3lPWS/R7uvk3MNMlBGowR5oOw== nicolasaiz173@gmail.com'
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
