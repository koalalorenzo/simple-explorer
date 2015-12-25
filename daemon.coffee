###
This is the Daemon that will take care to syncronize and access the information
on the blockchain. The daemon will configure and start the Node to allow
and control interactions with other bitcoin nodes.

At the moment we are using the bcoin library, but in future it may change.
###

bcoin = require 'bcoin'
net = require 'net'
fs = require 'fs'
levelup = require 'levelup'
leveldown = require 'leveldown'

# Standard bitcoin seeds
DEFAULT_CONFIGURATION = 
  max_connections: 32
  database_path: "#{process.env.HOME}/.spv_explorer"
  debug: false
  seeds: [
    'seed.bitcoin.sipa.be'
    'dnsseed.bluematt.me'
    'dnsseed.bitcoin.dashjr.org'
    'seed.bitcoinstats.com'
    'seed.bitnodes.io'
    'bitseed.xf2.org'
    'seed.bitcoin.jonasschnelli.ch'
  ]

class Daemon 
  constructor: (@configuration=DEFAULT_CONFIGURATION) ->
    # Define and start the pool!
    @_seeds = @configuration.seeds
    @_debug = @configuration.debug
    @_started = false
    @_txs = []
    @_blocks = []
    
    @storage = levelup(@configuration.database_path,
      db: leveldown
      valueEncoding: 'json'
    )
    return @

  start: ()->
    # Start the bcoin node (bcoin.pool)
    return if @_started is true

    @node = new bcoin.pool
      size: @configuration.max_connections
      storage: @storage
      
      createConnection: =>
        # Defining the way to create a new socket. We use a random seed.
        addr = @_seeds[(Math.random() * @_seeds.length) | 0]
        parts = addr.split(':')
        host = parts[0]
        port = +parts[1] or 8333
            
        socket = undefined
        socket = net.connect(port, host)
        
        socket.on 'error', -> 
          # This will prevent the program to exit when raising a socket error.
          return
        
        socket.on 'connect', -> 
          # If debugging, we will display it in the logs.
          console.log "Connected to {host}:#{port}" if @_debug
        
        return socket  
      
    # This will prevent problems when errors are raised:
    if not @_debug then @node.on 'error', -> return 
    return @
      
  stop: ->
    # Stop the node connections.
    @node.destroy()
    
  connect_to: (addr, port=8333) ->
    # Add an address to the available addresses in @_seed
    host = addr + ':' + port
    if not ~@_seeds.indexOf(host)
      console.log 'New peer added: %s', host if @_debug
      @_seeds.push host

  enable_debug_errors: (use_log=false)->
    # Use this method to return errors to the console
    if use_log
      @node.on 'error', (error) -> console.log(error)
    else
      @node.on 'error', (error) -> console.error(error)
    return @
    
  enable_autoconnect: ->
    # Use this method to automatically connect to new peers when these are 
    # discovered.
    @node.on 'addr', (data, peer) =>
      # When a new address is provided
      @connect_to data.ipv4, data.port
    return @
    
module.exports = Daemon