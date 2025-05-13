require 'aws-sdk-ec2'

log 'debug' do
  message 'Simian-debug: Start deploy.rb'
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
  'app_source' => {},
  'environment' => {}
}

app_path = "/srv/wordpress"


aws_ssm_parameter_store 'getAppSourceUrl' do
  path "/ApplyChefRecipes-Preset/#{component_name}/APP_SOURCE_URL"
  return_key 'APP_SOURCE_URL'
  action :get
end

aws_ssm_parameter_store 'getAppSourceRevision' do
  path "/ApplyChefRecipes-Preset/#{component_name}/APP_SOURCE_REVISION"
  return_key 'APP_SOURCE_REVISION'
  action :get
end

if false
  aws_ssm_parameter_store 'getCloudfrontDistribution' do
    path "/ApplyChefRecipes-Preset/#{component_name}/CLOUDFRONT_DISTRIBUTION"
    return_key 'CLOUDFRONT_DISTRIBUTION'
    action :get
  end
end

ruby_block "define-app" do
  block do
    app = {
      'app_source' => {
        'url' => node.run_state['APP_SOURCE_URL'],
        'revision' => node.run_state['APP_SOURCE_REVISION']
      },
      'environment' => {
        'CLOUDFRONT_DISTRIBUTION' => node.run_state['CLOUDFRONT_DISTRIBUTION']
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

execute 'Add an exception for this directory' do
  command "git config --global --add safe.directory #{app_path}"
  user "root"
end

execute "add key" do
  command "eval $(ssh-agent -s) && ssh-add /root/.ssh/id_rsa"
  action :run
end

git 'sync the repo' do
  depth 1
  repository lazy {app['app_source']['url']}
  revision lazy {app['app_source']['revision']}
  retries 3
  retry_delay 5
  destination '/srv/wordpress'
end

# make sure permissions are correct
execute "chown-data-www" do
  command "chown -R www-data:www-data #{app_path}"
  user "root"
  action :run
  not_if "stat -c %U #{app_path} | grep www-data"
end

# and now, W3TC's cloudfront config
cloudfront_config = ""

ruby_block 'cloudfront_edit' do
  block do
    if app['environment']['CLOUDFRONT_DISTRIBUTION']
      cloudfront_config = app['environment']['CLOUDFRONT_DISTRIBUTION']
      w3config = Chef::Util::FileEdit.new("#{app_path}/wp-content/w3tc-config/master.php")
      w3config.search_file_replace_line("cdn.cf2.id", "\"cdn.cf2.id\": \"#{cloudfront_config}\",")
      w3config.write_file
    end
  end
end

# Clean cache
service 'varnish' do
  action [:restart]
end

log 'debug' do
  message 'Simian-debug: End deploy.rb'
  level :info
end
