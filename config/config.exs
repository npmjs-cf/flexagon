# Flexagon Configuration File
use Mix.Config

# Flexagon currently exposes three toggles in configuration:
#  - target: the main npm registry
#  - scope_target: the npm registry used to scoped packages
#  - port: the HTTP port to listen for requests on
#
#  If this project is started directly, mix will load the configuration
#  from this file. Otherwise, mix will load the configuration from
#  *your* application.

config :flexagon, target: "registry.npmjs.cf"
config :flexagon, scope_target: "registry.npmjs.com"
config :flexagon, port: 4001

# The logger's default configuration doesn't include the Request Id
config :logger, :console, metadata: [:request_id]
