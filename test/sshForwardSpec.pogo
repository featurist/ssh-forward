sshForward = require '../index'
express = require 'express'
httpism = require 'httpism'
chai = require 'chai'
should = chai.should()
chaiAsPromised = require 'chai-as-promised'
chai.use(chaiAsPromised)

describe 'ssh forward' =>
  self.timeout 5000

  app = nil
  server = nil
  webAppPort = 12345
  client = httpism.api "http://localhost:#(webAppPort)"

  beforeEach
    app := express()
    server := app.listen (webAppPort)

    app.get '/' @(req, res)
      setTimeout ^ 100!
      res.send 'hi from web app'

    shouldNotBeAbleToConnect()!

  afterEach
    server.close()

  shouldNotBeAbleToConnect()! =
    httpism.get "http://localhost:23456/".should.eventually.be.rejectedWith 'connect ECONNREFUSED'!

  it 'can connect to the web app'
    client.get '/'!.body.should.equal 'hi from web app'

  it 'can connect to the web app through ssh'
    responseBodies = nil

    sshForward! {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @(port)
      responseBodies := [n <- [1..2], httpism.get "http://localhost:#(port)/"!.body]

    responseBodies.should.eql ['hi from web app', 'hi from web app']

  it 'when the block fails, it closes the port'
    sshForward {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @(port)
      @throw @new Error 'oh dear'
    .should.eventually.be.rejectedWith 'oh dear'!

    shouldNotBeAbleToConnect()!

  it 'can not connect to the web app after it has finished'
    sshForward {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    }! @{}

    httpism.get "http://localhost:23456/".should.eventually.be.rejectedWith (Error)

  it 'fails gracefully'
    privilegedPort = 80

    sshForward {
      hostname = 'localhost'
      localPort = privilegedPort
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @{}.should.eventually.be.rejectedWith r/ssh exited with 255: Privileged ports can only be forwarded by root./

  it 'can be passed an ssh command'
    privilegedPort = 80

    sshForward {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
      command = 'ssh -p 4000'
    } @{}.should.eventually.be.rejectedWith r/ssh exited with 255: ssh: connect to host localhost port 4000: Connection refused/

  it 'can open and close the port without a block'
    tunnel = sshForward! {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    }

    responseBody = httpism.get "http://localhost:#(tunnel.port)/"!.body
    responseBody.should.equal 'hi from web app'

    tunnel.close()!

    httpism.get "http://localhost:23456/".should.eventually.be.rejectedWith (Error)!
