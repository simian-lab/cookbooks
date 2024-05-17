# This recipe installs the required Software for a multiserver setup.
# In summary, it:
#
# 1. Installs the required packages, which are:
#     - NFS (for use with EFS)
#     - Memcached (for use with ElastiCache)
#
# 2. Makes sure the /wp-content/uploads, /wp-content/gallery and
# /wp-content/authors folders exist (the latter two only if required)
# 3. Mounts /wp-content/uploads, /wp-content/gallery and /wp-content/authors
# as EFS mounts.
#
# Keep in mind that the `deploy` recipe should be run *before* this one, since
# the default WordPress file layout must be present.
#
# — Ivan Vásquez (ivan@simian.co) / Jan 29, 2017

# Initial setup: just a couple vars we need
log 'debug' do
  message 'Simian-debug: Start multiserver.rb'
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

aws_ssm_parameter_store 'getEFSAuthors' do
  path "/ApplyChefRecipes-Preset/#{component_name}/EFS_AUTHORS"
  return_key 'EFS_AUTHORS'
  action :get
end

aws_ssm_parameter_store 'getEFSGallery' do
  path "/ApplyChefRecipes-Preset/#{component_name}/EFS_GALLERY"
  return_key 'EFS_GALLERY'
  action :get
end

aws_ssm_parameter_store 'getEFSUploads' do
  path "/ApplyChefRecipes-Preset/#{component_name}/EFS_UPLOADS"
  return_key 'EFS_UPLOADS'
  action :get
end

ruby_block "define-app" do
  block do
    app = {
      'environment' => {
        'EFS_AUTHORS' => node.run_state['EFS_AUTHORS'],
        'EFS_GALLERY' => node.run_state['EFS_GALLERY'],
        'EFS_UPLOADS' => node.run_state['EFS_UPLOADS']
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

# 1. We install the dependencies
package 'Install NFS' do
  case node[:platform]
  when 'redhat', 'centos'
    package_name 'nfs-utils'
  when 'ubuntu', 'debian'
    package_name 'nfs-common'
  end
end

# 2. We make sure that the folders exist
ruby_block 'create_authors_directory' do
  block do
    if app['environment']['EFS_AUTHORS']
      Chef::Log.info('Creating authors directory...')
      require 'fileutils'
      FileUtils.mkdir_p("#{app_path}/wp-content/authors")
      FileUtils.chown('www-data', 'www-data', "#{app_path}/wp-content/authors")
      FileUtils.chmod(0755, "#{app_path}/wp-content/authors")
    else
      Chef::Log.info('EFS_AUTHORS environment variable not set, skipping directory creation.')
    end
  end
  action :run
end

ruby_block 'create_gallery_directory' do
  block do
    if app['environment']['EFS_GALLERY']
      Chef::Log.info('Creating gallery directory...')
      require 'fileutils'
      FileUtils.mkdir_p("#{app_path}/wp-content/gallery")
      FileUtils.chown('www-data', 'www-data', "#{app_path}/wp-content/gallery")
      FileUtils.chmod(0755, "#{app_path}/wp-content/gallery")
    else
      Chef::Log.info('EFS_GALLERY environment variable not set, skipping directory creation.')
    end
  end
  action :run
end

ruby_block 'create_uploads_directory' do
  block do
    if app['environment']['EFS_UPLOADS']
      Chef::Log.info('Creating uploads directory...')
      require 'fileutils'
      FileUtils.mkdir_p("#{app_path}/wp-content/uploads")
      FileUtils.chown('www-data', 'www-data', "#{app_path}/wp-content/uploads")
      FileUtils.chmod(0755, "#{app_path}/wp-content/uploads")
    else
      Chef::Log.info('EFS_UPLOADS environment variable not set, skipping directory creation.')
    end
  end
  action :run
end

# 3. We mount the folders as EFS folders
ruby_block 'mount_authors' do
  block do
    if app['environment']['EFS_AUTHORS']
      Chef::Log.info('Mounting authors...')
      command = "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_AUTHORS']}:/ #{app_path}/wp-content/authors"
      Chef::Log.info("Executing command: #{command}")
      system(command)
    else
      Chef::Log.info('EFS_AUTHORS environment variable not set, skipping mount.')
    end
  end
  action :run
end

ruby_block 'mount_gallery' do
  block do
    if app['environment']['EFS_GALLERY']
      Chef::Log.info('Mounting gallery...')
      command = "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_GALLERY']}:/ #{app_path}/wp-content/gallery"
      Chef::Log.info("Executing command: #{command}")
      system(command)
    else
      Chef::Log.info('EFS_GALLERY environment variable not set, skipping mount.')
    end
  end
  action :run
end

ruby_block 'mount_uploads' do
  block do
    if app['environment']['EFS_UPLOADS']
      Chef::Log.info('Mounting uploads...')
      command = "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_UPLOADS']}:/ #{app_path}/wp-content/uploads"
      Chef::Log.info("Executing command: #{command}")
      system(command)
    else
      Chef::Log.info('EFS_UPLOADS environment variable not set, skipping mount.')
    end
  end
  action :run
end

if app['environment']['EFS_GALLERY']
  execute 'mount_gallery' do
    command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_GALLERY']}:/ #{app_path}/wp-content/gallery"
  end
end

log 'debug' do
  message 'Simian-debug: End multiserver.rb'
  level :info
end
