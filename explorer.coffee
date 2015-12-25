###
This is the Explorer, a set of method to extract easily information from the 
daemon.

At the moment we are using the bcoin library, but in future this may change.
###

bcoin = require "bcoin"

Daemon = require "./daemon"

class Explorer 
  constructor: (@daemon) ->
    @_txs_received = []
    @daemon = @daemon or new Daemon()
    @_debug = if @daemon._debug is not undefined then @daemon._debug else false
    return @
    
  get_loading_percentage: ->
    # Returns the percentage of blocks known.
    return @daemon.node.chain.fillPercent() * 100 | 0

  call_transaction: (tx_hash, callback) ->
    # Use a callback to get from peers a specific transaction
    console.log "Watching TX: #{tx_hash}" if @_debug
    
    @daemon.node.on 'tx', (_tx, _peer) =>
      hash = bcoin.utils.revHex(_tx.hash('hex')) 

      if hash is tx_hash and !~@_txs_received.indexOf(_tx)
        # Running the callback if it's the first time we see this tx
        console.log "TX Watched #{tx_hash}" if @_debug
        @_txs_received.push _tx
        callback _tx, _peer if callback

    @daemon.node.watch tx_hash

  call_block: (block_hash, callback) ->
    # Use a callback to get the object (JSON parsed?) of a block
    console.error "Work in progress... Sorry!"  
    process.exit(1)
    
  call_address_balance: (address_hash, callback) ->
    console.error "Work in progress... Sorry!"  
    process.exit(1)
 
module.exports = Explorer
