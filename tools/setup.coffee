# Deps
_ = require 'lodash'
cp = require 'child_process'
colors = require 'colors'
inquirer = require 'inquirer'

# Kick it off
console.log 'So you wanna use Wordpress, huh?\n'.yellow.bold

# Questions to ask user
questions = [
	{
		type: 'confirm'
		name: 'scaffold'
		message: 'Install scaffold?'
		default: false
	}
]

# Process user input
inquirer.prompt questions
.then (answers) ->
	installScaffold() if answers.scaffold

# Install the scaffold
installScaffold = ->
	console.log 'Example'
