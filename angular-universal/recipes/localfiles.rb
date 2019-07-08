# This recipe installs the required Software for a multiserver setup.
# In summary, it:
#
# 1. Install Dependencies and initial folders
#
# 2. Makes sure the /wp-content/uploads, /wp-content/gallery and
# /wp-content/authors folders exist (the latter two only if required)
#
# 3. Mounts /wp-content/uploads, /wp-content/gallery and /wp-content/authors
# as EFS mounts.
#
# — Sebastian Giraldo (sebastian@simian.co) / Jul 8, 2019

# Initial setup: just a couple vars we need
instance = search("aws_opsworks_instance", "self:true").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"
    app_path_imgs = "/srv/#{app['shortname']}_imgs"

    # We install the dependencies
    package 'Install NFS' do
      case node[:platform]
      when 'redhat', 'centos'
        package_name 'nfs-utils'
      when 'ubuntu', 'debian'
        package_name 'nfs-common'
      end
    end

    # Create Default dir
    directory "#{app_path_imgs}" do
      owner 'www-data'
      group 'www-data'
      mode '0755'
      action :create
    end

    # Create wp-content dir
    directory "#{app_path_imgs}/wp-content" do
      owner 'www-data'
      group 'www-data'
      mode '0755'
      action :create
    end

    # We make sure that the folders exist
    if app['environment']['EFS_UPLOADS']
      directory "#{app_path_imgs}/wp-content/uploads" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    if app['environment']['EFS_GALLERY']
      directory "#{app_path_imgs}/wp-content/gallery" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    if app['environment']['EFS_AUTHORS']
      directory "#{app_path_imgs}/wp-content/authors" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    # We mount the folders as EFS folders
    if app['environment']['EFS_UPLOADS']
      execute 'mount_uploads' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_UPLOADS']}:/ #{app_path_imgs}/wp-content/uploads"
      end
    end

    if app['environment']['EFS_GALLERY']
      execute 'mount_gallery' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_GALLERY']}:/ #{app_path_imgs}/wp-content/gallery"
      end
    end

    if app['environment']['EFS_AUTHORS']
      execute 'mount_authors' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_AUTHORS']}:/ #{app_path_imgs}/wp-content/authors"
      end
    end
  end
end