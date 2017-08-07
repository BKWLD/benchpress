###
This file exports an object that can be to merge configuration into some
defaults and then apply them to shipit
###

# Deps
_ = require 'lodash'
crypto = require 'crypto'
child_process = require 'child_process'
inquirer = require 'inquirer'
Slack = require 'node-slack'
shipitDeploy = require 'shipit-deploy'
shipitShared = require 'shipit-shared'
colors = require 'colors'

# The Bukwild slack webhook, shared between projects
slack = new Slack process.env.SLACK_WEBHOOK

# Receives the shipit object and config that should be merged in
module.exports = {}
module.exports.init = (shipit, config) ->

	# Load shipit plugins
	shipitDeploy(shipit)
	shipitShared(shipit)

	# Prep some shared vars
	workspace = "/tmp/#{config.appName}-#{getEnvironment()}"

	# The default config
	defaults =
		default:
			workspace: workspace               # Where the deploy gets prepped locally
			repositoryUrl: getOrigin()         # The repo URL
			ignores: [                         # Don't copy these up
				'.git', 'node_modules', '.env', '.DS_Store'
			]

			# Config for symlinked directories
			shared:
				overwrite: true
				triggerEvent: false
				files: [
					'.env'
				]
				dirs: [
					{ path: 'public/wp-content/uploads', chmod: '-R 775' }
				]

		# Merge staging settings with some defaults
		staging:
			branch: 'master'  # The branch to pull from
			keepReleases: 1

		# Merge production settings with some defaults
		production:
			branch: 'production'
			keepReleases: 3

	# Merge stages into the default config and pass to Shipit
	shipit.initConfig _.defaultsDeep(config, defaults)

	# ############################################################################
	# Events

	# Tasks that get run before shipit begins
	shipit.on 'deploy', ->
		shipit.start 'slack start' if config.slackChannel

	# After git repo is pulled locally, do yarn installs and then webpack compile
	shipit.on 'fetched', ->
		shipit.start ['composer', 'compile']

	# After the the remote is updated, run post commands
	shipit.on 'updated', ->
		shipit.start ['env:create', 'shared']

	# Tasks that get run when shipit ends (the `deployed` even't wasnt firing)
	shipit.on 'cleaned', ->
		shipit.start 'slack end' if config.slackChannel

	# ############################################################################
	# Local tasks

	# Run the Webpack compile task, which is dependant on node dependencies
	shipit.blTask 'compile', ['composer', 'yarn'], ->
		shipit.local 'yarn minify', { cwd: workspace }

	# Install node dependencies
	shipit.blTask 'yarn', ->
		shipit.local 'yarn install', { cwd: workspace }

	# Install composer dependencies locally so that composer.phar doesn't need to
	# be added the the repository
	shipit.blTask 'composer', ->
		shipit.local 'composer install', { cwd: workspace }

	# ############################################################################
	# Manipulate .env files

	# Vars
	env_path = "#{shipit.config.deployTo}/shared/.env"

	# On initial deploy, prompt user for .env values
	shipit.blTask 'env:create', (done) ->

		# Check if any of the app servers are missing .env files
		shipit.remote "[ -f \"#{env_path}\" ] && echo 1 || echo 0"
		.then (servers) ->

			# If all servers have an env file, do nothing
			return done() if !_.find(servers, (server) -> server.stdout.trim() == '0')

			# Ask user questions to populate the .env file
			shipit.log '\nNo .env file on remote. Creating using your answers:'.yellow.bold
			inquirer.prompt firstDeployQuestions(), (answers) ->

				# Write the env file to the server after converting the answers object
				# to a multiline string
				env = _.map(answers, (val, key) -> "#{key}=#{val}").join("\n")
				shipit.remote "mkdir -p '#{shipit.config.deployTo}/shared'"
				.then -> shipit.remote "echo '#{env}' > #{env_path}"

				# Create the database if it doesn't exist
				.then ->
					shipit.log 'Creating database if it doesn\'t exist...'
					shipit.remote "mysql
						-h #{answers.DB_HOST}
						-u #{answers.DB_USERNAME}
						-p#{answers.DB_PASSWORD}
						-e 'CREATE DATABASE IF NOT EXISTS `#{answers.DB_DATABASE}`'"

				# Done with this task
				.then -> done()

		# Prevent the promise from being returned
		return

	# Read the env file
	shipit.blTask 'env:get', ->
		getEnv().then (servers) ->
			shipit.log servers[0].stdout.yellow
	getEnv = ->
		shipit.remote "mkdir -p '#{shipit.config.deployTo}/shared'"
		.then -> shipit.remote "touch #{env_path}"
		.then -> shipit.remote "cat #{env_path}"

	# Write a key-vlaue pair to the .env file
	shipit.blTask 'env:set', (done) ->

		# Ask user what key-value is being touched
		shipit.log '\nSupply the key-value pair you want to add:'.yellow.bold
		inquirer.prompt [
			{ type: 'input', name: 'key',   message: 'Key'   }
			{ type: 'input', name: 'value', message: 'Value' }
		], (answers) ->

			# Get the .env contents from each server, creating the .env file if needed
			getEnv().then (servers) ->
				env = servers[0].stdout.trim()

				# If the key is already in the .env, update the value
				pair = answers.key + '=' + answers.value
				if env.search(new RegExp('^' + answers.key + '=', 'm')) > -1
					env = env.replace(new RegExp('^' + answers.key + '=.*$', 'm'), pair)

				# Otherwise, append to the file
				else
					env += "\n" + pair

				# Write the updated env file
				shipit.remote "echo '#{env}' > #{env_path}"
			.then -> done() # Done

	# ############################################################################
	# Project management tasks

	# Tell Slack about deploy starting
	shipit.blTask 'slack start', -> slack.send
		username: 'Starting deployment'
		text: ":clock1: *#{getDeveloperName()}* is deploying to *#{getEnvironment()}*"
		channel: config.slackChannel

	# Tell Slack about deploy finished
	shipit.blTask 'slack end', -> slack.send
		username: 'Finished deployment'
		text: ":checkered_flag: #{shipit.config.url}"
		channel: config.slackChannel

# ##############################################################################
# Utils - Helpers used in the Shipit config
# ##############################################################################

# Determine the repository URL by using the git `origin` remote
getOrigin = ->
	child_process
	.execSync('git config --local --get remote.origin.url')
	.toString('utf8')
	.trim()

# Get the environment that is being deployed to
getEnvironment = -> process.argv[2]

# Get someone's git username and return a promise
getDeveloperName = ->
	name = child_process.execSync 'git config user.name'
	names = name.toString('utf8').trim().split(' ')
	return "#{names[0]} #{names[1][0]}."

# Muster the questions to prompt the user on initial deploy
firstDeployQuestions = ->
	[
		{
			type:    'input'
			name:    'APP_ENV'
			message: 'Environment'
			default:  getEnvironment()
		}
		{
			type:    'input'
			name:    'DB_HOST'
			message: 'Database host'
			default: 'localhost'
		}
		{
			type:    'input'
			name:    'DB_NAME'
			message: 'Database name'
		}
		{
			type:    'input'
			name:    'DB_USERNAME'
			message: 'Database user'
		}
		{
			type:    'input'
			name:    'DB_PASSWORD'
			message: 'Database pass'
		}
	]
