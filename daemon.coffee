###
This is the Daemon, a class designed to take care of the connections, to save
the right information required of the blockchain locally and emit events when 
observing specific elements of the blockchain (blocks, addresses, transactions)

Since Daemon extends EventEmitter, when an block a transaction or some info are
received and processed, an event is emitted. Example:

  daemon.on "a14811ceb4a53a8d700ab184fa0d3c6be0ae9f22c56ac32af012e00f6737a670", (block) ->
    # We found the block!
    console.log block

The daemon requests all the blocks headers

###
EventEmitter = require('events')
bitcore = require('bitcore-lib')
bitcore_p2p = require('bitcore-p2p')
levelup = require('level')

Pool = bitcore_p2p.Pool
Inventory = bitcore_p2p.Inventory
BufferUtil = bitcore.util.buffer

DEFAULT_SETTINGS =
  node: # bitcoire-p2p pool options:
    maxSize: 32
    relay: false
    dnsSeed: true
    listenAddr: true
  debug: false
  workdir: path.join process.env.HOME, ".simple-explorer/"
    
class Daemon extends EventEmitter
  constructor: (@settings=DEFAULT_SETTINGS) ->
    @node = new Pool(@settings.node)
    
    @_debug = @settings.debug or false
    @_intervals = []
    
    @storage = levelup(@settings.workdir)
    
    @_inventory = []
    @_txs = []
    @_blocks = []
    @_is_started = false
    return @

  start: (listen=true)->
    # Start the bitcoin pool and connect to other peers. 
    return if @is_connected()
  
    # Set up the event listner for transactions
    @node.on 'peerblock', (peer, message) =>
      @_on_block(peer, message)
    
    # Set up the event listner for transactions
    @node.on 'peertx', (peer, message) =>
      @_on_tx(peer, message)
  
    # Set up the event listner for NotFound messages
    @node.on 'peernotfound', (peer, message) =>
      @_on_not_found(peer, message)
    
    # Set up the event listner for getdata messages
    @node.on 'peergetdata', (peer, message) =>
      @_on_data(peer, message)
      
    # Set up the event listner for inventory messages
    @node.on 'peerinv', (peer, message) =>
      @_on_inventory(peer, message)
    
    @storage.open() if @storage.isClosed()
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
    @storage.close() if @storage.isOpen()

    @emit "stopped"
    @_is_started = false
    return @
    
  is_connected: ->
    # Validate if the Daemon's node is connected to the network.
    return (@node.numberConnected() > 0) or (@_is_started is true)

  ###
  # Callbacks for data collection and "emit" events
  ###

  _on_getdata: (peer, message) ->
    # When some node is requesting some info using getdata.
    return

  _on_tx: (peer, message)->
    # This method is used when a peer provide a transaction
    for content in message.inventory when content.type is Inventory.TYPE.TX
      @_inventory.push content
      
      if !~ @_txs.indexOf(content)
        @_txs.push(content)
        @emit "tx", message

        reverse_hash = BufferUtil.reverse(content.hash).toString('hex')
        @emit "#{reverse_hash}", content
    return

  _on_block: (peer, message)->
    # This method is used when a peer provide a block
    console.log "FUCK YEAH WE RECEIVED A BLOCK"
    if !~ @_blocks.indexOf(message.block)
      @_blocks.push(message.block)
      @emit "block", message.block

      # reverse_hash = BufferUtil.reverse(message.hash).toString('hex')
      # @emit "#{reverse_hash}", message
    return
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    @emit "notfound", message
    return 
     
  _on_inventory: (peer, message)->
    # This method is used when a peer provide its inventory
    @emit "inv", message
    
    for content in message.inventory
      console.log "INVENTORY RECEIVED FROM #{peer.ip} TYPE: #{content.type}"
      @_inventory.push content
            
      switch content.type
        when Inventory.TYPE.BLOCK then @_request_block content.hash
        # when Inventory.TYPE.TX then @request_tx content.hash
        # when Inventory.TYPE.FILTERED_BLOCK then 
    return

  _connectTo: (addr)->
    # Connect to a specific Peer
    @node._addAddr(addr)    
    return
    
  ###
  # Sending messages to other peers
  ###

  _request_block: (hash, peer=null)->
    # Send a message to a peer (optional) requiring a specific block.
    messages = new bitcore_p2p.Messages()
    message = messages.GetData.forBlock(hash)
    
    if peer 
      peer.sendMessage message
    else
      @broadcast_message message, time_gap=0

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