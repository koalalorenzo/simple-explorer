###
Main file for the SPV explorer.
This should be the executable that will runt the Daemon, and connect API to it
using the Exporer methods.
###
Daemon = require './daemon'
Explorer = require './explorer'


daemon_instance = new Daemon()
daemon_instance.debug = true
daemon_instance.enable_debug_errors(use_log=true)
daemon_instance.enable_autoconnect()

explorer_instance = new Explorer(daemon_instance.pool)

# setInterval ()->
# 	console.log "Loading status:", explorer_instance.status(), "%"
# , 5000