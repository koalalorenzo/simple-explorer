###
This is the Daemon, a class designed to take care of the connections, to save
the right information required of the blockchain locally and emit events when 
observing specific elements of the blockchain (blocks, addresses, transactions)

###
Pool = require('bitcore-p2p').Pool
EventEmitter = require('events')

DEFAULT_SETTINGS =
  node: # bitcoire-p2p pool options:
    maxSize: 32
    relay: false
    dnsSeed: true
    listenAddr: true

class Daemon extends EventEmitter
  constructor: (@settings=DEFAULT_SETTINGS) ->
    @node = new Pool(@settings.node)
    
    @_debug = @settings.debug
    @_intervals = []
    
    @_inventory = []
    @_txs = []
    @_blocks = []
    return @

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

    @emit "started"
    
    return @
  
  stop: ->
    # Stop the connections, destroy the intervals
    for _interval in @_intervals
      clearInterval _interval
    @node.disconnect()

    @emit "stopped"
    return @
    
  ###
  # Callbacks for data collection (storage) and "emit" events
  ###

  _on_tx: (peer, message)->
    # This method is used when a peer provide a transaction
    callback(message) if callback

    if !~ @_txs.indexOf(message)
      @_txs.push(message) 
      @emit "tx", message

    console.log "Transaction:", message if @_debug
    return
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    @emit "notfound", message
    return 
     
  _on_inventory: (peer, message)->
    # This method is used when a peer provide its inventory
    @_inventory.push message.inventory[0]
    console.log "Inventory:", message if @_debug
    @emit "inv", message
    return

  _connectTo: (addr)->
    # Connect to a specific Peer
    @node._addAddr(addr)    
    return

  broadcast_message: (message, time_gap=15000, max_attemps=5)->
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
    
module.exports = Daemon
module.exports.DEFAULT_SETTINGS = DEFAULT_SETTINGS