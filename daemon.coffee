###
This is the Daemon that will take care to syncronize and access the information
on the blockchain. The daemon is a configured bcoin.pool object.
###

bcoin = require 'bcoin'
net = require 'net'
fs = require 'fs'
levelup = require 'levelup'
leveldown = require 'leveldown'

# Standard bitcoin seeds

DEFAULT_CONFIGURATION = 
  max_connections: 32
  database_path: process.env.HOME + '/.bcoin'
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
    enable_debug_errors: (use_log=false)->
      # Use this method to return errors to the console
      if use_log
        @pool.on 'error', (error) -> console.log(error)
      else
        @pool.on 'error', (error) -> console.error(error)
      
    enable_autoconnect: ->
      # Use this method to automatically connect to new peers when these are 
      # discovered.
      @pool.on 'addr', (data, peer) =>
        # When a new address is provided
        host = data.ipv4 + ':' + data.port
        if not ~@seeds.indexOf(host)
          console.log 'Found new peer: %s', host if @debug
          @seeds.push host
        return
        
    constructor: (@configuration=DEFAULT_CONFIGURATION) ->
      # Define and start the pool!
      @seeds = @configuration.seeds
      @debug = @configuration.debug

      @storage = levelup(@configuration.database_path,
        db: leveldown
        valueEncoding: 'json'
      )

      @pool = new (bcoin.pool)(
        size: @configuration.max_connections
        storage: @storage
        
        createConnection: =>
          # Defining the way to create a new socket. We use a random seed.
          addr = @seeds[(Math.random() * @seeds.length) | 0]
          parts = addr.split(':')
          host = parts[0]
          port = +parts[1] or 8333
                
          socket = undefined
          socket = net.connect(port, host)
          socket.on 'error', -> return
          return socket  
      )
      
      # This will prevent problems when errora are raised:
      if not @debug then @pool.on 'error', -> return 
      return @
module.exports = Daemon