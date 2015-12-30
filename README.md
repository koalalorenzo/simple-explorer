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


## How to contribute
To know what is left to do, run the tests!

    npm install -g mocha 
    npm test

If a test is failing, it means that some work is required to implement that 
feature, imrpove that test or verify manually what is wrong... and remember to
write KISS code!

If you don't know how to code, but you want to support this project, donate 
some satoshi to this address: 18ib128yA9WqapKEWw1MSkaJJPrhixyL1L