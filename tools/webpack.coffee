# Deps
config = require 'camo/tools/webpack' # Load config from Camo
_ = require 'lodash'
path = require 'path'

# Vars concerned with the env
hmr = process.argv[1].includes 'webpack-dev-server'
minify = process.env.NODE_ENV == 'production'

# Change the entry points
module.exports = (options) ->

	# Set default options
	options = _.defaults options,
		theme: path.resolve process.cwd(), 'public/wp-content/themes/site'
		themePublicPath: '/wp-content/themes/site/'

	# Set context to the assets dir of the theme
	config.context = path.resolve options.theme, 'assets'

	# Update the entry points
	config.entry = app: './boot.coffee'

	# Output files within the theme
	config.output.path = path.resolve options.theme, 'dist'
	config.output.publicPath =
		if hmr
		then 'http://localhost:' + port + options.themePublicPath
		else options.themePublicPath

	# Return the tweaked config
	return config
