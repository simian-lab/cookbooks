# This recipe installs the required Software for a multiserver setup.
# In summary, it:
#
# 1. The AMI must have the required packages, which are:
#     - NFS (for use with EFS)
#
# 2. Makes sure the /wp-content/uploads, /wp-content/gallery and
# /wp-content/authors folders exist (the latter two only if required)
# 3. Mounts /wp-content/uploads, /wp-content/gallery and /wp-content/authors
# as EFS mounts.
#
# Keep in mind that the `deploy` recipe should be run *before* this one, since
# the default WordPress file layout must be present.
#
# — Sebastian Giraldo (sebastian@simian.co) / Jun 28, 2019

# Initial setup: just a couple vars we need
instance = search("aws_opsworks_instance", "self:true").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"

    # We make sure that the folders exist
    if app['environment']['EFS_UPLOADS']
      directory "#{app_path}/wp-content/uploads" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    if app['environment']['EFS_GALLERY']
      directory "#{app_path}/wp-content/gallery" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    if app['environment']['EFS_AUTHORS']
      directory "#{app_path}/wp-content/authors" do
        owner 'www-data'
        group 'www-data'
        mode '0755'
        action :create
      end
    end

    # We mount the folders as EFS folders
    if app['environment']['EFS_UPLOADS']
      execute 'mount_uploads' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_UPLOADS']}:/ #{app_path}/wp-content/uploads"
      end
    end

    if app['environment']['EFS_GALLERY']
      execute 'mount_gallery' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_GALLERY']}:/ #{app_path}/wp-content/gallery"
      end
    end

    if app['environment']['EFS_AUTHORS']
      execute 'mount_authors' do
        command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_AUTHORS']}:/ #{app_path}/wp-content/authors"
      end
    end
  end
end