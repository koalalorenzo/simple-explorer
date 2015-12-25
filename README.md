# Simple Explorer: the SPV Explorer
Simple Explorer is a **BIP-37 programmable** blockchain explorer.
It is designed to be a SPV Bitcoin node using NodeJS, to develop KISS pieces 
of software using the blockchain, without downloading the all the full blocks

The project will include a blockchain explorer as a proof of concept and 
example to help developers, and build something *useful*. Now it provide only 
a CLI

**Note**: Still under heavy development, please help and contribute with issues
or pull requests :-)

## Installation and Usage
After downloading the source code, run these commands inside the directory to
install all the requirements.

    npm install -g coffee
    npm install 
    
This will install CoffeeScript and dependencies, everything required at the
moment to run the main script.

Once ready, the CLI to the explorer is `main.coffee`. To get some help run:

    coffee main.coffee --help

