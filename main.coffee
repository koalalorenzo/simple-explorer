###
Main file for the SPV Blockchain Explorer.
This should be the executable that will runt the Daemon, and connect API to it
using the Exporer methods.

The reason we need a Daemon and an Explorer, is that the daemon will should 
take care of the "node" connections and configuration and the Explorer should 
use the same node instance, but call different methods.
###
cli_args = require('optimist')
          .demand('tx')
          .alias('tx', 'transaction')
          .describe('tx', 'Transaction hex hash')

          .boolean('sync')
          .alias('s', 'sync')
          .describe('sync', 'Download the blockchain information')
          .default('sync', false)
 
          .boolean('debug')
          .alias('d', 'debug')
          .describe('debug', 'Enable debug messages')
          .default('debug', false)

          .boolean('json')
          .describe('json', 'Use json output')
          .default('json', false)
 
          .argv
          
Daemon = require './daemon'
Explorer = require './explorer'

# Start the daemon
daemon_instance = new Daemon()
daemon_instance._debug = args.debug
daemon_instance.enable_debug_errors(use_log=args.debug)
daemon_instance.enable_autoconnect()

# Create the explorer
explorer_instance = new Explorer(daemon_instance)

if cli_args.argv.sync
  setInterval ()->
    peers = daemon_instance.node.peers.length
    percentage = explorer_instance.get_loading_percentage()-1
    console.log("peers #{peers}, #{percentage}% loaded.")
  , 60000
  
else if cli_args.argv.tx
    explorer_instance.call_transaction cli_args.argv.tx, (tx)->
      console.log tx.toJSON()