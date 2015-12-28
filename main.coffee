###
Main file for the SPV Blockchain Explorer.
This should be the executable that will runt the Daemon, and connect API to it
using the Exporer methods.

The reason we need a Daemon and an Explorer, is that the daemon will should 
take care of the "node" connections and configuration and the Explorer should 
use the same node instance, but call different methods.
###
optimist = require('optimist')
          .usage("Create a new Bitcoin SPV node and request data from nodes.")
          .string('transaction')
          .alias('transaction', 't')
          .describe('transaction', 'Get a transaction from its hex hash')

          .string('block')
          .alias('block', 'b')
          .describe('block', 'Get a block from its hex hash')

          .string('address')
          .alias('address', 'a')
          .describe('address', 'Get the balance from an Address')

          .boolean('sync')
          .alias('sync', 's')
          .describe('sync', 'Download the blockchain information')
          .default('sync', false)
 
          .boolean('debug')
          .alias('debug', 'd')
          .describe('debug', 'Enable debug messages')
          .default('debug', false)
           
Explorer = require './explorer'
Daemon = require './daemon'

# Instances:
daemon = undefined
explorer = undefined 

###
# Methods
###

get_explorer = (args) ->
  # Start the node!
  daemon = new Daemon()
  daemon.start()

  explorer = new Explorer(daemon)
  return [explorer, daemon]

exit = (args)->
  console.log("Closing the process in 1 second...") if args.debug == true
  daemon.stop()
  setTimeout ()->
    process.exit 0
  , 1500

###
# Parsing the CLI options and running methods:
###

if optimist.argv.sync
  [explorer, daemon] = get_explorer(optimist.argv)
  
else if optimist.argv.address
  # Get the balance of an Address
  [explorer, daemon] = get_explorer(optimist.argv)

  explorer.call_address_balance optimist.argv.address, (_balance)->
    console.log _balance.toJSON()
    exit(optimist.argv)

else if optimist.argv.block
  # Get a block
  [explorer, daemon] = get_explorer(optimist.argv)

  explorer.call_block optimist.argv.block, (_block)->
    console.log _block.toJSON()
    exit(optimist.argv)
  
else if optimist.argv.transaction
  # Get a transaction
  [explorer, daemon] = get_explorer(optimist.argv)

  explorer.call_transaction optimist.argv.transaction, (_tx)->
    console.log _tx.toJSON()
    exit(optimist.argv)  
    
else
  console.log optimist.help()
  process.exit 1