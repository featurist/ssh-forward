spawn = require 'child_process'.spawn
net = require 'net'
parseCommand = require 'shell-quote'.parse

module.exports (options, block) =
  sshCommand = parseSshCommand(options.command)

  ssh = spawn(sshCommand.ssh, [
    options.hostname
    "-L#(options.localPort):#(options.remoteHost):#(options.remotePort)"
    '-N'
    '-oBatchMode=yes'
    sshCommand.args
    ...
  ])

  waitToOpen(options.localPort, ssh)!

  if (block)
    try
      block(options.localPort)!
    finally
      closed = waitFor (ssh) toClose
      ssh.kill()
      closed!
  else
    {
      port = options.localPort

      close ()! =
        closed = waitFor (ssh) toClose
        ssh.kill()
        closed!
    }

parseSshCommand (command) =
  if (command)
    args = parseCommand(command)
    { ssh = args.0, args = args.slice(1) }
  else
    { ssh = 'ssh', args = [] }

waitFor (ssh) toClose! =
  promise! @(result, error)
    ssh.on 'exit' @(code)
      result()

waitToOpen (port, ssh) =
  keepTrying = true

  setTimeout
    keepTrying := false
  5000

  promise @(result, error)
    errorStream = stream (ssh.stderr) toString

    ssh.on 'exit' @(code)
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
