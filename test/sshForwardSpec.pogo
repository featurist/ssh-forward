sshForward = require '../index'
express = require 'express'
httpism = require 'httpism'
chai = require 'chai'
should = chai.should()
chaiAsPromised = require 'chai-as-promised'

chai.use(chaiAsPromised)

describe 'ssh forward'
  app = nil
  server = nil
  webAppPort = 12345
  client = httpism.api "http://localhost:#(webAppPort)"

  beforeEach
    app := express()
    server := app.listen (webAppPort)

    app.get '/' @(req, res)
      res.send 'hi from web app'

    shouldNotBeAbleToConnect()!

  afterEach
    server.close()

  shouldNotBeAbleToConnect()! =
    httpism.get "http://localhost:23456/".should.eventually.be.rejectedWith 'connect ECONNREFUSED'!

  it 'can connect to the web app'
    client.get '/'!.body.should.equal 'hi from web app'

  it 'can connect to the web app through ssh' =>
    self.timeout 5000
    responseBody = nil

    sshForward! {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @(port)
      responseBody := httpism.get "http://localhost:#(port)/"!.body
    
    responseBody.should.equal 'hi from web app'

  it 'when the block fails, it closes the port' =>
    self.timeout 5000

    sshForward {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @(port)
      @throw @new Error 'oh dear'
    .should.eventually.be.rejectedWith 'oh dear'!

    shouldNotBeAbleToConnect()!

  it 'can not connect to the web app after it has finished' =>
    self.timeout 5000

    sshForward {
      hostname = 'localhost'
      localPort = 23456
      remoteHost = 'localhost'
      remotePort = webAppPort
    }! @{}

    httpism.get "http://localhost:23456/".should.eventually.be.rejectedWith (Error)

  it 'fails gracefully' =>
    self.timeout 5000

    privilegedPort = 80

    sshForward {
      hostname = 'localhost'
      localPort = privilegedPort
      remoteHost = 'localhost'
      remotePort = webAppPort
    } @{}.should.eventually.be.rejectedWith r/ssh exited with 255: Privileged ports can only be forwarded by root./
