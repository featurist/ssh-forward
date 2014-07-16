spawn = require 'child_process'.spawn
net = require 'net'

module.exports (options, block) =
  ssh = spawn('ssh', [
    options.hostname
    "-L#(options.localPort):#(options.remoteHost):#(options.remotePort)"
    '-N'
    '-oBatchMode=yes'
  ])

  waitToOpen(options.localPort, ssh)!

  if (block)
    try
      block(options.localPort)!
    finally
      ssh.kill()
      waitFor (ssh) toClose!
  else
    {
      port = options.localPort

      close ()! =
        ssh.kill()
        waitFor (ssh) toClose!
    }

waitFor (ssh) toClose! =
  promise! @(result, error)
    ssh.on 'close' @(code)
      result()

waitToOpen (port, ssh) =
  keepTrying = true

  setTimeout
    keepTrying := false
  5000

  promise @(result, error)
    errorStream = stream (ssh.stderr) toString

    ssh.on 'close' @(code)
      keepTrying := false
      if (code != 0)
        error(@new Error "ssh exited with #(code): #(errorStream!)")

    attemptConnectionUntilTimeout (port) =
      try
        attemptConnection(port)!
      catch (e)
        if (keepTrying)
          attemptConnectionUntilTimeout(port)!

    attemptConnectionUntilTimeout(port)!
    result()

attemptConnection (port) =
  promise @(result, error)
    socket = @new net.Socket()
    connection = socket.connect(port)
    connection.on 'connect'
      connection.end()
      result()

    connection.on 'error' @(e)
      error(e)

stream (s) toString! =
  promise @(result, error)
    s.setEncoding 'utf-8'

    text = []

    s.on 'data' @(data)
      text.push(data)

    s.on 'error' @(data)
      error (@new Error (data))

    s.on 'end'
      result (text.join '')
