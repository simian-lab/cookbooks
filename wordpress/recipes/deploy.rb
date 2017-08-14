app = search("aws_opsworks_app","deploy:true").first
app_path = "/srv/#{app['shortname']}"

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
  command "chown -R www-data:www-data #{app_path}"
  user "root"
  action :run
  not_if "stat -c %U #{app_path} | grep www-data"
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