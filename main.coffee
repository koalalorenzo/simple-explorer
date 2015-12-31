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
          .describe('transaction', 'Get a transaction from its hash')

          .string('block')
          .alias('block', 'b')
          .describe('block', 'Get a block from its hash')

          .string('header')
          .alias('header', 'h')
          .describe('header', "Get a block's header from its hash")

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
           
Daemon = require './daemon'
Explorer = require './explorer'

# Instances:
daemon = undefined
explorer = undefined 

###
# Methods
###

# Start the node! It will return an array with the explorer and the daemon.
# @param {Object} args - process arguments parsed by optimist
# @returns {Array} [explorer,daemon] - An array with the Explorer and the Daemon
setup_and_start = (args) ->
  daemon = new Daemon()
  daemon._debug = args.debug
  daemon.start()

  explorer = new Explorer(daemon.settings, daemon)
  return [explorer, daemon]

# Quit
# @param {Object} args - process arguments parsed by optimist
exit = (args)->
  daemon.stop()
  console.log("Closing the process in 1 second...") if args.debug == true
  setTimeout ()->
    process.exit 0
  , 1500

# Start the daemon in order to downlaod the blockchain headers into the db.
# It will start the daemon, as soon as a peer is connected, the inventory
# should be provided (and requested), this will allows the daemon to ask for
# blocks and block's headers. When a block or block's header is received
# the daemon will check if the previous block's header are saved in the 
# database, if not it will start looking for that.
# 
# After few 30s from the start, a second periodic check shoud verify that all
# the blocks' headers have a link (the previous block's header is in the db)
# if not it will be required from the network.
# @param {Object} args - process arguments parsed by optimist
syncronize = (args)->
  [explorer, daemon] = setup_and_start(optimist.argv)
  
  setInterval ()->
    daemon.request_missing_blocks_headers()
  , 30000

###
# Parsing the CLI options and running methods:
###

if optimist.argv.sync
  syncronize()

else if optimist.argv.address
  # Get the balance of an Address
  [explorer, daemon] = setup_and_start(optimist.argv)

  explorer.call_address_balance optimist.argv.address, (_balance)->
    console.log JSON.stringify _balance.toJSON()
    daemon.stop()
    exit(optimist.argv)

else if optimist.argv.header
  # Get a block's hash
  [explorer, daemon] = setup_and_start(optimist.argv)
  
  explorer.call_block_header optimist.argv.header, (_header)->
    console.log JSON.stringify _header.toJSON()
    daemon.stop()
    exit(optimist.argv)
  
else if optimist.argv.block
  # Get a block
  [explorer, daemon] = setup_and_start(optimist.argv)

  explorer.call_block optimist.argv.block, (_block)->
    console.log JSON.stringify _block.toJSON()
    daemon.stop()
    exit(optimist.argv)
  
else if optimist.argv.transaction
  # Get a transaction
  [explorer, daemon] = setup_and_start(optimist.argv)

  explorer.call_transaction optimist.argv.transaction, (_tx)->
    console.log JSON.stringify _tx.toJSON()
    daemon.stop()
    exit(optimist.argv)  
    
else
  console.log optimist.help()
  process.exit 1
  