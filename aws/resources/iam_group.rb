property :group_name, String, name_property: true
property :path, String, default: '/'
property :members, Array, default: []
property :remove_members, true, default: true
property :policy_members, Array, default: []
property :remove_policy_members, true, default: true
property :region, String, default: lazy { fallback_region }

# authentication
property :aws_access_key, String
property :aws_secret_access_key, String, sensitive: true
property :aws_session_token, String, sensitive: true
property :aws_assume_role_arn, String
property :aws_role_session_name, String

include AwsCookbook::Ec2 # needed for aws_region helper

action :create do
  if group_exists?(new_resource.group_name)
    # POLICIES
    # check for updated managed policies
    resp = iam.list_attached_group_policies(group_name: new_resource.group_name)
    new_policies = new_resource.policy_members
    resp.attached_policies.each do |policy|
      # delete removed policies if new_resource.remove_policy_members == true
      if !new_resource.policy_members.include?(policy.policy_arn) && new_resource.remove_policy_members == true
        converge_by("detatch #{policy.policy_arn} from group #{new_resource.group_name}") do
          Chef::Log.debug("detatch #{policy.policy_arn} from group #{new_resource.group_name}")
          iam.detach_group_policy(
            group_name: new_resource.group_name,
            policy_arn: policy.policy_arn
          )
        end
      end
      # remove policies that are present from the new policies to add
      new_policies.delete(policy.policy_arn) if new_resource.policy_members.include?(policy.policy_arn)
    end
    # add any leftover new policies if they exist.
    unless new_policies.empty?
      converge_by("attach new policies to group #{new_resource.group_name}: #{new_policies.join(',')}") do
        new_policies.each do |policy|
          iam.attach_group_policy(
            group_name: new_resource.group_name,
            policy_arn: policy
          )
        end
      end
    end
    # USERS
    # logic same for policies, but but different calls and stuff of course
    resp = iam.get_group(group_name: new_resource.group_name)
    new_users = new_resource.members
    resp.users.each do |user|
      # delete removed users if new_resource.remove_members == true
      if !new_resource.members.include?(user.user_name) && new_resource.remove_members == true
        converge_by("remove user #{user.user_name} from group #{new_resource.group_name}") do
          iam.remove_user_from_group(
            group_name: new_resource.group_name,
            user_name: user.user_name
          )
        end
      end
      # remove users that are present from the new users to add
      new_users.delete(user.user_name) if new_resource.members.include?(user.user_name)
    end
    # add any leftover new policies if they exist.
    unless new_users.empty?
      converge_by("add new users to group #{new_resource.group_name}: #{new_users.join(',')}") do
        new_users.each do |user|
          iam.add_user_to_group(
            group_name: new_resource.group_name,
            user_name: user.to_s
          )
        end
      end
    end
  else
    converge_by("add new group #{new_resource.group_name}") do
      iam.create_group(
        path: new_resource.path,
        group_name: new_resource.group_name
      )
      # attach group members (user)
      new_resource.members.each do |member|
        iam.add_user_to_group(
          group_name: new_resource.group_name,
          user_name: member
        )
      end
      # attach group members (policy)
      new_resource.policy_members.each do |policy|
        iam.attach_group_policy(
          group_name: new_resource.group_name,
          policy_arn: policy
        )
      end
    end
  end
end

action :delete do
  if group_exists?(new_resource.group_name)
    converge_by("delete group #{new_resource.group_name}") do
      # un-attach associated entities (users, policies)
      resp = iam.get_group(group_name: new_resource.group_name)
      resp.users.each do |user|
        iam.remove_user_from_group(
          group_name: new_resource.group_name,
          user_name: user.user_name
        )
      end
      resp = iam.list_attached_group_policies(group_name: new_resource.group_name)
      resp.attached_policies.each do |policy|
        iam.detach_group_policy(
          group_name: new_resource.group_name,
          policy_arn: policy.policy_arn
        )
      end
      # delete the group
      iam.delete_group(group_name: new_resource.group_name)
    end
  end
end

action_class do
  include AwsCookbook::IAM

  # group_exists - logic for checking if the group exists
  def group_exists?(group_name)
    resp = iam.get_group(group_name: group_name)
    if !resp.empty?
      true
    else
      false
    end
  rescue ::Aws::IAM::Errors::NoSuchEntity
    false
  end
end
