###
This is the Daemon, a class designed to take care of the connections, to save
the right information required of the blockchain locally and emit events when 
observing specific elements of the blockchain (blocks, addresses, transactions)

Since Daemon extends EventEmitter, when an block a transaction or some info are
received and processed, an event is emitted. Example:

  daemon.on "a14811ceb4a53a8d700ab184fa0d3c6be0ae9f22c56ac32af012e00f6737a670", (block) ->
    # We found the block!
    console.log block

###
Pool = require('bitcore-p2p').Pool
EventEmitter = require('events')
bitcore = require('bitcore-lib')
BufferUtil = bitcore.util.buffer

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
    @_is_started = false
    return @

  start: (listen=true)->
    # Start the bitcoin pool and connect to other peers. 
    return if @is_connected()
    
    # Set up the event listner for transactions
    @node.on 'peertx', (peer, message) ->
      @_on_tx(peer, message)
  
    # Set up the event listner for NotFound messages
    @node.on 'peernotfound', (peer, message)->
      @_on_not_found(peer, message)
    
    # Set up the event listner for getdata messages
    @node.on 'peergetdata', (peer, message)->
      @_on_data(peer, message)
      
    # Set up the event listner for inventory messages
    @node.on 'peerinv', (peer, message) ->
      @_on_inventory(peer, message)
    
    @node.connect()
    @node.listen() if listen

    @emit "started"
    @_is_started = true
    return @
  
  stop: ->
    # Stop the connections, destroy the intervals
    for _interval in @_intervals
      clearInterval _interval
    @node.disconnect()

    @emit "stopped"
    @_is_started = false
    return @
    
  is_connected: ->
    # Validate if the Daemon's node is connected to the network.
    return (@node.numberConnected() > 0) or (@_is_started is true)

  ###
  # Callbacks for data collection and "emit" events
  ###

  _on_data: (peer, message) ->
    for content in message.inventory
       @_inventory.push content

    @emit "getdata", message

  _on_tx: (peer, message)->
    # This method is used when a peer provide a transaction
    for content in message.inventory
      @_inventory.push content
      
      if !~ @_txs.indexOf(content)
        @_txs.push(content)
        @emit "tx", message

        reverse_hash = BufferUtil.reverse(content.hash).toString('hex')
        @emit "#{reverse_hash}", content

    return
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    @emit "notfound", message
    return 
     
  _on_inventory: (peer, message)->
    # This method is used when a peer provide its inventory
    for content in message.inventory
      @_inventory.push content
      
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