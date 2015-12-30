###
Tests to verify the behaviour when interacting with blocks 
###
temp = require 'temp'
chai = require 'chai'
bitcore = require('bitcore-lib')

BufferUtil = bitcore.util.buffer
BlockHeader = bitcore.BlockHeader
Daemon = require '../daemon'
Explorer = require '../explorer'

temp.track() # Delete temporary files at exit
chai.should()

describe 'Block Header', ->
  SETTINGS = Daemon.DEFAULT_SETTINGS
  SETTINGS.workdir = temp.mkdirSync "simple-explorer"
  console.log SETTINGS
  daemon = new Daemon(SETTINGS)
  explorer = new Explorer(daemon.settings, daemon)
  
  # Loading a block headers from hex, hash: 000000000000000009a578ae2d8de2b1e554a7d8e40d6c48d8ac214c387065ce
  fake_header = BlockHeader.fromString('04000000ed377a6d9e8e8082bda9957510bc56dc13fd47a8d14a5e0a0000000000000000ce9b0b7302006ba2692d9d43d2810201bde8524c0c572e32ba39d8fdef8d7393cc24845609c40b18f03308b0')

  it 'should be injected in the database', (done) ->
    fake_header.hash.should.equal "000000000000000009a578ae2d8de2b1e554a7d8e40d6c48d8ac214c387065ce"   
    daemon.save_header fake_header, (_err) ->
      done()

  it 'should be extracted directly from the database correctly', (done)->
    daemon.cb_get_header "000000000000000009a578ae2d8de2b1e554a7d8e40d6c48d8ac214c387065ce", (err, _block) ->
      previous_hash = _block.prevHash.toString('hex')
      previous_hash.should.equal "00000000000000000a5e4ad1a847fd13dc56bc107595a9bd82808e9e6d7a37ed"
      done()
      
  it 'should be extracted from the explorer', (done)->
    explorer.call_block_header "000000000000000009a578ae2d8de2b1e554a7d8e40d6c48d8ac214c387065ce", (block)->
      header.hash.should.equal fake_header.header.hash
      done()