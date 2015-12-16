###
This is the Explorer, a set of method to extract easily information from the 
daemon.
###

class Explorer 
    constructor: (@pool, @configuration={}) ->

   	status: ->
	     return @pool.chain.fillPercent() * 100 | 0

module.exports = Explorer
