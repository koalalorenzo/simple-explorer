###
This is the Explorer, designed to interact with the Daemon to extract info from
the blocks saved or ask the nodes for missing new data.
###

Daemon = require("./daemon")
bitcore_p2p = require('bitcore-p2p')

class Explorer
  constructor: (@settings=Daemon.DEFAULT_SETTINGS, @daemon=null) ->
    @daemon = new Daemon(@settings) if not @daemon
    @bloom_filter = new bitcore_p2p.BloomFilter.create(1)
    return @

  call_transaction: (tx_hash, callback) ->
    # Use a callback to get the object of a transaction
    # Remember, it will only access transactions in the mempool
    # read more here:https://en.bitcoin.it/wiki/Protocol_documentation#getdata
    messages = new bitcore_p2p.Messages()
    message = messages.GetData.forTransaction(tx_hash)
    message_inv = messages.Inventory.forTransaction(tx_hash)

    @daemon.on tx_hash, callback
      
    @daemon.broadcast_message message, time_gap=15000
    @daemon.broadcast_message message_inv, time_gap=12000

    return @

  call_block: (block_hash, callback) ->
    # Use a callback to get the object of a block
    messages = new bitcore_p2p.Messages()
    message = messages.GetData.forBlock(block_hash)
    
    @daemon.on block_hash, callback
      
    @daemon.broadcast_message message, time_gap=15000
    return @
    
  call_address_balance: (address_hash, callback) ->
    console.error "Work in progress... Sorry!"  
    # process.exit(1)
 
module.exports = Explorer
