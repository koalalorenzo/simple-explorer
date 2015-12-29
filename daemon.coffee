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
path = require('path')
levelup = require('levelup')
EventEmitter = require('events')
bitcore = require('bitcore-lib')
bitcore_p2p = require('bitcore-p2p')

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
    @_block_hashes = []
    @_bestHeight = 0
    
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
          
    # Set up the event listner for inventory messages
    @node.on 'peerinv', (peer, message) =>
      @_on_inventory(peer, message)

    # Set up the event listner when a connection happen
    @node.on 'peerready', (peer, message) =>
      @_on_peer_connected(peer, message)
      if @_debug
        console.log "CONNECT", peer.version, peer.subversion, peer.bestHeight

    # Set up the event listner when a peer disconnects
    @node.on 'peerdisconnect', (peer, message) =>
      if @_debug
        console.log "DISCONN", peer.version, peer.subversion, peer.bestHeight

    @storage.open() if @storage.isClosed()
    @node.connect()
    @node.listen() if listen
    
    @emit "started"
    @_is_started = true
    console.log "Daemon started" if @_debug
    return @
  
  stop: ->
    # Stop the connections, destroy the intervals
    for _interval in @_intervals
      clearInterval _interval

    @node.disconnect()
    @storage.close() if @storage.isOpen()

    @emit "stopped"
    @_is_started = false
    console.log "Daemon stopped" if @_debug
    return @
    
  is_connected: ->
    # Validate if the Daemon's node is connected to the network.
    return (@node.numberConnected() > 0) or (@_is_started is true)

  ###
  # Callbacks for data collection and "emit" events
  ###

  _on_peer_connected: (peer, message) ->
    # This method is used when a peer is connected.

    if peer.bestHeight > @_bestHeight
      # if the peer has a bigger Height, ask for his inventory
      @_request_inv(peer)
      @_bestHeight = peer.bestHeight

  _on_block: (peer, message)->
    # This method is used when a peer provide a block. It will save the headers
    # in the db and emit the event related to the block's hash.
    block = message.block

    if !~ @_blocks.indexOf(block)
      @_blocks.push(block)

    @emit "block", block

    # Saving the headers in the DB if not already there
    @storage.get "headers/#{block.hash}", (err, old_header) =>
      return if not err
      console.log "Block received: #{block.hash}" if @_debug
      @storage.put "headers/#{block.hash}", block.headers

    # ToDo: Understand if we are interested in this block by inspecting its
    #       content, then save the entire block too.
    # @storage.get "blocks/#{block.hash}", (err, old_block) =>
    #   return if not err
    #   @storage.put "blocks/#{block.hash}", block

  
    @emit "#{block.hash}", block
    return
     
  _on_inventory: (peer, message)->
    # This method is used when a peer provide its inventory
    @emit "inv", message
    
    for content in message.inventory
      @_inventory.push content
            
      switch content.type

        when Inventory.TYPE.BLOCK
          # If we don't have the headers of this block, request it!
          @storage.get "headers/#{content.hash}", (err, cont) =>
            @_request_block content.hash if err

        # when Inventory.TYPE.TX then @request_tx content.hash
        # when Inventory.TYPE.FILTERED_BLOCK then 
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
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    @emit "notfound", message
    return 
    
  ###
  # Sending messages to other peers
  ###
  
  _request_inv: (peer=null)->
    # Request the inventory to a peer (optional)
    messages = new bitcore_p2p.Messages()
    message = messages.GetBlocks()

    if peer 
      peer.sendMessage message
    else
      @broadcast_message message, time_gap=0
    
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