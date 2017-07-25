# Deps
camo = require 'camo/tools/webpack' # Load config from Camo
_ = require 'lodash'
path = require 'path'

# Export a closure so that the theme can be overidden
module.exports = (options) ->

	# Set default options
	options = _.defaults options,
		theme: path.resolve process.cwd(), 'public/wp-content/themes/site'
		themePublicPath: '/wp-content/themes/site/'

	# Pass Benchpress overrides as options to camo and return the webpack config
	return camo ({hmr}) ->

		# Set context to the assets dir of the theme
		context: path.resolve options.theme, 'assets'

		# Output files within the theme
		output:
			path: path.resolve options.theme, 'dist'
			publicPath:
				if hmr
				then 'http://localhost:' + port + options.themePublicPath
				else options.themePublicPath
