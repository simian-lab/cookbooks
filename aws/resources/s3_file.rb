property :path, String, name_property: true
property :remote_path, String
property :region, String, default: lazy { fallback_region }
property :bucket, String
property :requester_pays, [true, false], default: false
property :owner, String, regex: Chef::Config[:user_valid_regex]
property :group, String, regex: Chef::Config[:group_valid_regex]
property :mode, [String, nil]
property :checksum, [String, nil]
property :backup, [Integer, false], default: 5
property :headers, Hash
property :use_etag, [true, false], default: true
property :use_last_modified, [true, false], default: true
property :atomic_update, [true, false], default: true
property :force_unlink, [true, false], default: false
property :manage_symlink_source, [true, false]
property :virtual_host, [true, false], default: false
property :s3_url, String
# Intentionally not using platform_family?('windows') due to a bug/issue
# where this method is not abvailable in the context of gating properties
# TODO: update when this is fixed
if node['platform_family'] == 'windows' # rubocop:disable ChefStyle/UsePlatformHelpers
  property :inherits, [true, false], default: true
  property :rights, Hash
end

# authentication
property :aws_access_key, String
property :aws_secret_access_key, String, sensitive: true
property :aws_session_token, String, sensitive: true
property :aws_assume_role_arn, String
property :aws_role_session_name, String

include AwsCookbook::Ec2 # needed for aws_region helper

# allow use of the old aws_access_key_id property
alias_method :aws_access_key_id, :aws_access_key

action :create do
  do_s3_file(:create)
end

action :create_if_missing do
  do_s3_file(:create_if_missing)
end

action :delete do
  do_s3_file(:delete)
end

action :touch do
  do_s3_file(:touch)
end

action_class do
  include AwsCookbook::Ec2

  def s3
    require 'aws-sdk-s3'

    Chef::Log.debug('Initializing the S3 Client')
    @s3 ||= create_aws_interface(::Aws::S3::Client, region: new_resource.region)
  end

  def s3_obj
    require 'aws-sdk-s3'
    remote_path = new_resource.remote_path.dup
    remote_path.sub!(%r{^/*}, '')

    Chef::Log.debug("Initializing the S3 Object for bucket: #{new_resource.bucket} path: #{remote_path}")
    @s3_obj ||= ::Aws::S3::Object.new(bucket_name: new_resource.bucket, key: remote_path, client: s3)
  end

  class ::File
    def each_part(part_size)
      yield read(part_size = part_size) until eof?
    end
  end

  def calculate_multipart_md5(file_path, part_size)
    file = ::File.open(file_path, 'rb')
    hashes = []

    file.each_part(part_size) do |part|
      hashes << ::Digest::MD5.hexdigest(part)
    end

    file.close

    multipart_hash = ::Digest::MD5.hexdigest([hashes.join].pack('H*'))
    "#{multipart_hash}-#{hashes.count}"
  end

  def compare_md5s(remote_object, local_file_path)
    return false unless ::File.exist?(local_file_path)
    local_md5 = ::Digest::MD5.new
    remote_hash =
      case new_resource.requester_pays
      when true
        # Calling head_object explicitly (bypassing automatic call via the
        # remote_object's etag method) to add the request_payer option
        s3.head_object(
          bucket: remote_object.bucket.name,
          key: remote_object.key,
          request_payer: 'requester'
        ).etag.delete('"') # etags are always quoted
      else
        remote_object.etag.delete('"') # etags are always quoted
      end

    if remote_hash.to_s =~ /\-/
      # Calculate the remote file chunk size of the original multi part upload
      chunk_count_from_etag = Integer(remote_hash.split('-')[1])
      file_size_mb = Float(remote_object.size) / 1024 / 1024
      chunks = (file_size_mb / chunk_count_from_etag).ceil
      multi_part_upload_chunk_size = chunks * 1024 * 1024
      local_hash = calculate_multipart_md5(local_file_path, multi_part_upload_chunk_size)
    else
      ::File.open(local_file_path, 'rb') do |f|
        f.each_line do |line|
          local_md5.update line
        end
      end
      local_hash = local_md5.hexdigest
    end

    Chef::Log.debug "Remote file md5 hash:  #{remote_hash}"
    Chef::Log.debug "Local file md5 hash:   #{local_hash}"

    local_hash == remote_hash
  end

  def s3_url
    utc_offset = Time.new.utc_offset
    s3_url_params = { expires_in: 300 + utc_offset.abs }
    s3_url_params[:request_payer] = 'requester' if new_resource.requester_pays
    s3_url_params[:virtual_host] = true if new_resource.virtual_host
    s3url = s3_obj.presigned_url(:get, s3_url_params).gsub(%r{https://([\w\.\-]*)\.\{1\}s3.amazonaws.com:443}, 'https://s3.amazonaws.com:443/\1') # Fix for ssl cert issue
    Chef::Log.debug("Using S3 URL #{s3url}")
    @s3_url ||= s3url
  end

  def do_s3_file(resource_action)
    md5s_match = false

    if resource_action == :create
      if compare_md5s(s3_obj, new_resource.path)
        Chef::Log.info("Remote and local files appear to be identical, skipping #{resource_action} operation.")
        md5s_match = true
      else
        Chef::Log.info("Remote and local files do not match, running #{resource_action} operation.")
      end
    end

    remote_file new_resource.name do
      path new_resource.path
      source s3_url
      owner new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      mode new_resource.mode if new_resource.mode
      checksum new_resource.checksum if new_resource.checksum
      backup new_resource.backup
      headers new_resource.headers if new_resource.headers
      use_etag new_resource.use_etag
      use_last_modified new_resource.use_last_modified
      atomic_update new_resource.atomic_update
      force_unlink new_resource.force_unlink
      manage_symlink_source new_resource.manage_symlink_source
      sensitive new_resource.sensitive
      retries new_resource.retries
      retry_delay new_resource.retry_delay
      if platform_family?('windows')
        inherits new_resource.inherits
        rights new_resource.rights
      end
      action resource_action
      not_if { md5s_match }
    end
  end
end
