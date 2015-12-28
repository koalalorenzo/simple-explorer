###
This is the Explorer, a set of method to extract easily information from the 
daemon.

At the moment we are using the bcoin library, but in future this may change.
###

Pool = require('bitcore-p2p').Pool
Messages = require('bitcore-p2p').Messages

DEFAULT_SETTINGS =
  node: # bitcoire-p2p pool options:
    maxSize: 32
    relay: false
    dnsSeed: true
    listenAddr: true
    

class Explorer 
  constructor: (@settings=DEFAULT_SETTINGS) ->
    @node = new Pool(@settings.node)
    
    @_intervals = []
    @_watch_tx_callbacks = {}
    @_watch_blocks_callbacks = {}
    @_debug = @settings.debug
    
    @_inventory = []
    @_txs = []
    @_blocks = []
    return @

  ###
  # Connections
  ###
  start: (listen=true)->
    # Start the bitcoin pool and connect to other peers. 
    return if @node.numberConnected() > 0
    
    # Set up the event listner for transactions
    @node.on 'peertx', (peer, message) ->
      @_on_tx(peer, message)
  
    # Set up the event listner for NotFound messages
    @node.on 'peernotfound', (peer, message)->
      @_on_not_found(peer, message)

    # Set up the event listner for inventory messages
    @node.on 'peerinv', (peer, message) ->
      @_on_inventory(peer, message)
    
    @node.connect()
    @node.listen() if listen

    return @
  
  stop: ->
    # Stop the connections, destroy the intervals
    for _interval in @_intervals
      clearInterval _interval
    @node.disconnect()
    return @

  _on_tx: (peer, message)->
    # This method is used when a peer provide a transaction
    callback(message) if callback

    @_txs.push(message) if !~ @_txs.indexOf(message)

    # Disabled for testing
    # if @_watch_tx_callbacks.hasOwnProperty(message.transaction.id)
    #   @_watch_tx_callbacks[message.transaction.id].forEach (callback) ->
    #     callback(message) if typeof callback is "function"

    console.log "Transaction:", message if @_debug
    return
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    return 
     
  _on_inventory: (peer, message)->
    # This method is used when a peer provide its inventory
    @_inventory.push message.inventory[0]
    console.log "Inventory:", message if @_debug
    return

  _connectTo: (addr)->
    # Connect to a specific Peer
    @node._addAddr(addr)    
    return

  _broadcastMessage: (message, time_gap=15000, max_attemps=5)->
    # Set an interval (default 15sec) to broadcast a Message to the
    # peers connected. If the time_gap option is set to 0, it will just
    # broadcast the message once. It will try several times (default 5) and 
    # and then the interval will be remved. This is to prevent spam.
    @node.sendMessage message
    
    if time_gap > 0
      new_interval = setInterval =>
          console.log "Broadcasting a message:", message if @_debug
          @node.sendMessage message
        , time_gap
      @_intervals.push new_interval
    return
    
  ###
  # Messages and Requests
  ###
  call_transaction: (tx_hash, callback) ->
    # Use a callback to get the object of a transaction
    # Remember, it will only access transactions in the mempool
    # read more here:https://en.bitcoin.it/wiki/Protocol_documentation#getdata
    messages = new Messages()
    message = messages.GetData.forTransaction(tx_hash)
    message_inv = messages.Inventory.forTransaction(tx_hash)

    if not @_watch_tx_callbacks[tx_hash]
      @_watch_tx_callbacks[tx_hash] = new Array(callback)
    else 
      @_watch_tx_callbacks[tx_hash].push callback 
      
    @_broadcastMessage message, time_gap=15000
    @_broadcastMessage message_inv, time_gap=12000

    return @

  call_block: (block_hash, callback) ->
    # Use a callback to get the object of a block
    messages = new Messages()
    message = messages.GetData.forBlock(block_hash)
    
    if not @_watch_blocks_callbacks[block_hash]
      @_watch_blocks_callbacks[block_hash] = new Array(callback)
    else 
      @_watch_blocks_callbacks[block_hash].push callback 
      
    @_broadcastMessage message, time_gap=15000
    return @
    
  call_address_balance: (address_hash, callback) ->
    console.error "Work in progress... Sorry!"  
    # process.exit(1)
 
module.exports = Explorer
