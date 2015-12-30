###
Tests to verify the behaviour when interacting with blocks 
###
temp = require 'temp'
chai = require 'chai'

Block = require('bitcore-lib').Block
Daemon = require '../daemon'
Explorer = require '../explorer'

temp.track() # Delete temporary files at exit
chai.should()

describe 'Block', ->
  SETTINGS = Daemon.DEFAULT_SETTINGS
  SETTINGS.workdir = temp.mkdirSync "simple-explorer"
  console.log SETTINGS
  daemon = new Daemon(SETTINGS)
  explorer = new Explorer(daemon.settings, daemon)
  
  # Loading a block from hex, hash: 000000004ff664bfa7d217f6df64c1627089061429408e1da5ef903b8f3c77db
  fake_block = Block.fromString('01000000459f16a1c695d04282fd9f84f4fe771121d467e5497eb1aa8bf66d8000000000cf7ef5b5c22d4edf641f0fd5fcfbcefa30acaa2fbc910206f8773e3918748504c1586e49ffff001d398eff7a0101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0804ffff001d027904ffffffff0100f2052a010000004341042d9a7f300e87b4877f0f601d9c4a1a387e159681bb1623339f6124bf5f3c60a0695fa295cba1d6162a81bcc91a8fe67eceaaefb151db2a5053e1ba7e78b0c9b2ac00000000')

  it 'should be injected in the database', (done) ->
    fake_block.hash.should.equal "000000004ff664bfa7d217f6df64c1627089061429408e1da5ef903b8f3c77db"   
    daemon.save_block fake_block, (_err) ->
      done()

  it 'should be extracted directly from the database', (done)->
    daemon.cb_get_block "000000004ff664bfa7d217f6df64c1627089061429408e1da5ef903b8f3c77db", (err, _block) ->
      _block.transactions[0].hash.should.equal "04857418393e77f8060291bc2faaac30facefbfcd50f1f64df4e2dc2b5f57ecf"
      done()
      
  it 'should be extracted from the explorer', (done)->
    explorer.call_block "000000004ff664bfa7d217f6df64c1627089061429408e1da5ef903b8f3c77db", (block)->
      block.header.hash.should.equal fake_block.header.hash
      done()