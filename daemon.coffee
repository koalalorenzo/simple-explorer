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

path = require('path')
levelup = require('levelup')
EventEmitter = require('events')
bitcore = require('bitcore-lib')
bitcore_p2p = require('bitcore-p2p')

Block = bitcore.Block
BlockHeader = bitcore.BlockHeader
BufferUtil = bitcore.util.buffer
Pool = bitcore_p2p.Pool
Inventory = bitcore_p2p.Inventory

DEFAULT_SETTINGS =
  node: # bitcoire-p2p pool options:
    maxSize: 8
    relay: false
    dnsSeed: true
    listenAddr: true
  debug: false
  workdir: path.join process.env.HOME, ".simple-explorer/"
    
class Daemon extends EventEmitter
  constructor: (@settings=DEFAULT_SETTINGS) ->
    @node = new Pool(@settings.node)
    @_best_peer = null
    
    @_debug = @settings.debug or false
    @_intervals = []
    
    @storage = levelup(@settings.workdir)
    @_blocks_headers_known = [] # Used to avoid multipe callbacks
    
    @_is_started = false
    
    #Debug values
    @_last_block = null
    @_last_inventory = []
    return @

  # Start the bitcoin pool and connect to other peers. 
  start: (listen=true)->
    return if @is_connected()
 
    # Set up the event listner for transactions
    @node.on 'peerheaders', (peer, message) =>
      @_on_block_headers(peer, message)
  
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
        console.log "CONNECTED: #{peer.host}:#{peer.port}"

    # Set up the event listner when a peer disconnects
    @node.on 'peerdisconnect', (peer, message) =>      
      console.log "DISCONNECTED: #{peer.host}:#{peer.port}" if @_debug

    @storage.open() if @storage.isClosed()
    @node.connect()
    @node.listen() if listen
    
    @emit "started"
    @_is_started = true
    console.log "Daemon started" if @_debug
    return @
  
  # Stop the connections, destroy the intervals
  stop: ->
    for _interval in @_intervals
      clearInterval _interval

    @node.disconnect()
    @storage.close() if @storage.isOpen()

    @emit "stopped"
    @_is_started = false
    console.log "Daemon stopped" if @_debug
    return @
    
  # Validate if the Daemon's node is connected to the network.
  is_connected: ->
    return (@node.numberConnected() > 0) and (@_is_started is true)

  ###
  # Common database interactions
  ###
  
  # Save a header in the database.
  save_header: (header, cb=null)->
    return if not header
    string_header = JSON.stringify(header.toJSON())
    @storage.put "headers/#{header.hash}", string_header, (err)->
      cb(err) if cb

  # Call the callback (cb) with the header object.
  cb_get_header: (hash, cb) ->
    @storage.get "headers/#{hash}", (_err, _head) ->
      if not _err and _head
        _head = new BlockHeader(JSON.parse(_head))
      cb(_err, _head)

  # Save a block in the database.
  save_block: (block, cb=null)->
    return if not block
    string_header = JSON.stringify(block.toJSON())
    @storage.put "blocks/#{block.hash}", string_header, (err)->
      cb(err) if cb

  # Call the callback (cb) with the block object.
  cb_get_block: (hash, cb) ->
    @storage.get "blocks/#{hash}", (_err, _block) ->
      if not _err and _block
        _block = new Block(JSON.parse(_block))
      cb(_err, _block)

  # This method will check the database and request the missing headers to
  # the other peers.
  request_missing_blocks_headers: ->
    @storage.createReadStream()
      .on 'data', (data) =>
        # Getting from the stream, only the headers
        return if not ~data.key.indexOf("headers/") or not data.value

        header = JSON.parse(data.value)
        # Now If the previous header is not available, request it
        @_request_block_if_hash_is_missing header.prevHash, no

      .on 'end', () =>
        console.log "Missing headers check completed" if @_debug

  # Check if the block's hash is missing from the db. Then reqeust it to the
  # peers connected.
  _request_block_if_hash_is_missing: (prev_hash, recursive=no) ->
    @cb_get_header prev_hash, (_err, _obj) =>
      if _err and prev_hash
        console.log "Headers missing: #{prev_hash}" if @_debug
        @_request_block prev_hash
      
      # Check recursively for missing previous hashes.
      if recursive and _obj
        # console.log "Checking: #{_obj.prevHash}" if @_debug
        @_request_block_if_hash_is_missing _obj.prevHash

  ###
  # Callbacks for data collection and "emit" events
  ###
  
  # This method is used when a peer is connected.
  _on_peer_connected: (peer, message) ->
    
    # Initally, best_peer is null
    if not @_best_peer
      @_best_peer = peer

    if peer.bestHeight >= @_best_peer.bestHeight
      # if the peer has a bigger Height, ask for his inventory
      @_request_blocks(peer)
      @_best_peer = peer

  # This method is called when a peer provide a block's headers. It will the
  # object in the db and emit the event related to the block's hash headers.
  _on_block_headers: (peer, message)->
    @_last_message = message
    @emit "headers", message.headers

    message.headers.forEach (header) =>
      # Ignore if this block is already known
      return if ~@_blocks_headers_known.indexOf header.hash
      @_blocks_headers_known.push header.hash

      # if a block's headers is not in the db, let's save it
      @cb_get_header header.hash, (err, obj) =>
        return if not err
        @save_header header 
        console.log "Headers received: #{header.hash}" if @_debug

  # This method is used when a peer provide a block. It will save the headers
  # in the db and emit the event related to the block's hash.
  _on_block: (peer, message)->
    block = message.block

    @emit "block", block
    @emit "#{block.hash}", block
    @_last_block = block
          
    # Saving the headers in the DB if not already there
    @cb_get_header block.hash, (err, old_header) =>
      return if not err
      @save_header block.header
      console.log "Block received: #{block.hash}" if @_debug
    # @_request_block_if_hash_is_missing block.header.toJSON().prevHash

    # ToDo: Understand if we are interested in this block by inspecting its
    #       content, then save the entire block too.
  
    return
     
  # This method is used when a peer provide its inventory
  _on_inventory: (peer, message)->
    @emit "inv", message
    @_last_inventory = message

    for content in message.inventory
      switch content.type

        when Inventory.TYPE.BLOCK
          # If we don't have the headers of this block, request it!
          reverse_hash = BufferUtil.reverse(content.hash).toString('hex')
          @cb_get_header reverse_hash, (err, obj) =>
            return if not err
            console.log "INV BLOCK:", reverse_hash
            @_request_block reverse_hash, peer
            # The peer does not provide the headers if after a INV we send a 
            # getHeaders method. Requesting the block provided.
            # @_request_block_headers reverse_hash, null, peer
            
        # when Inventory.TYPE.TX then @request_tx content.hash
        # when Inventory.TYPE.FILTERED_BLOCK then 
    return

  # This method is used when a peer provide a transaction
  # reverse_hash = BufferUtil.reverse(tx_hash).toString('hex')
  _on_tx: (peer, message)->
    # @emit "#{tx_hash}", content
    return
        
  _on_not_found: (peer, message)->
    # This method is used when a peer answer a Not found message
    console.log "NOT FOUND:", message if @_debug
    @emit "notfound", message
    return 
    
  ###
  # Sending messages to other peers
  ###
  
  # Request the inventory to a peer (optional)
  _request_blocks: (peer=null)->
    messages = new bitcore_p2p.Messages()
    message = messages.GetBlocks()

    console.log "Requesting Blocks" if @_debug
    if peer 
      peer.sendMessage message
    else
      @broadcast_message message, time_gap=0
    
  _request_block_headers: (hash_start, hash_stop=null, peer=null)->
    # Send a message to a peer (optional) requiring a specific block headers.
    options =
      starts: [hash_start]

    if hash_stop
      options.stop = hash_stop

    console.log "Requesting block headers: #{hash_start}" if @_debug

    messages = new bitcore_p2p.Messages()
    message = messages.GetHeaders(options)
    
    if peer 
      peer.sendMessage message
    else
      @broadcast_message message, time_gap=0
    
  # Send a message to a peer (optional) requiring a specific block.
  _request_block: (hash, peer=null)->
    messages = new bitcore_p2p.Messages()
    message = messages.GetData.forBlock(hash)
    
    console.log "Requesting block: #{hash}" if @_debug
    if peer 
      peer.sendMessage message
    else
      @broadcast_message message, time_gap=0

  # Set an interval (default 15sec) to broadcast a Message to the
  # peers connected. If the time_gap option is set to 0, it will just
  # broadcast the message once. It will try several times (default 5) and 
  # and then the interval will be remved. This is to prevent spam.
  broadcast_message: (message, time_gap=15000, max_attemps=5)->
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