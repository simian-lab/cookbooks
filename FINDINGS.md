# Findings: wordpress/recipes/default.rb

## Bugs

### 1. `varnish_variables` always has empty values (lines 486-493)
The hash is built at compile time when `error_page`, `cors`, `url_exclusions`,
`host_exclusions`, `browser_cache`, and `force_ssl_dns` are still `""`. The
`ruby_block` resources that populate them run at converge time, after the hash
has already captured the empty values. As a result, the VCL template never
receives error page, CORS headers, URL/host exclusions, or browser cache config.

**Fix:** Build `varnish_variables` inside a `ruby_block` that runs before the
template, or use `lazy {}` in the template's `variables()` call.

### 2. Duplicate resource names (Chef silently ignores the first definition)
- `ruby_block "insert_env_vars"` — defined at lines 303 and 324
- `ruby_block "log_app"` — defined at lines 178 and 495
- `execute "change permissions to key"` — defined at lines 561 and 570

In the case of `insert_env_vars`, the one at line 303 (Apache envvars) is
skipped entirely, meaning environment variables are never written to
`/etc/apache2/envvars`.

**Fix:** Give each resource a unique name.

### 3. `app['environment']['PHP_SSH_ENABLE']` always evaluates to `false` (line 296)
This is a compile-time condition, but `app['environment']` is populated inside
`ruby_block "define-app"` which runs at converge time. The PHP SSH extension is
never installed regardless of the SSM parameter value.

**Fix:** Move the condition inside a `ruby_block`, or read the value directly
from `node.run_state` at converge time.

---

## Code Smells

### 4. Hard-coded `component_name` → domain mapping (lines 346-378)
A chain of `if` statements maps CloudFormation stack names to domains. Every new
client requires modifying the cookbook. Should be driven by an SSM parameter or
a node attribute instead.

### ~~5. `===` instead of `==` for string comparison (lines 77, 346-375)~~ ✓ Fixed in 5811cd2
~~Works by coincidence in Ruby but is semantically incorrect. Use `==`.~~

### ~~6. `sudo` inside `execute` resources (lines 189, 195)~~ ✓ Fixed in 5f4fe0e
~~Chef already runs as root. The `sudo` prefix is redundant and could cause issues
if `sudo` is not configured for the Chef user.~~

### 7. Wasted EC2 API call (lines 68-69)
`describe_instances` is called and its result is immediately overwritten by
`describe_tags` on line 70. The first call serves no purpose.

### 8. `mkdir ~/.ssh/` without a guard (line 553)
Will raise an error if the directory already exists. Should use a `directory`
resource with `not_if { ::Dir.exist?('/root/.ssh') }`.
