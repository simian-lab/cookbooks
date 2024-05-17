name 'buddypress'
maintainer 'Simian'
maintainer_email 'ivan@simian.co'
license 'all_rights'
description 'Installs/Configures buddypress'
long_description 'Installs/Configures buddypress'
version '0.1.0'

depends 'application', '~> 5.0'
depends 'application_git', '~> 1.1.0'
depends 'apt', '~> 5.0.1'
depends 'chef_nginx', '~> 5.0.6'
depends 'apache2', '~> 3.2.2'
depends 'php', '~> 2.2.0'
depends 'varnish', '~> 3.0.0'
depends 'mysql', '~> 8.0'
depends 'aws', '~> 8.0'
depends 'aws-sdk-core', '~> 2'

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/buddypress/issues' if respond_to?(:issues_url)

# The `source_url` points to the development reposiory for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/buddypress' if respond_to?(:source_url)
