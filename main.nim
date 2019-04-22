import tables, strutils, threadpool, net, locks
import nativesockets
import asyncnet, asyncdispatch
# {.experimental.}

var clients {.threadvar.}: seq[Socket]
var database {.threadvar.}: Table[string, string]
database = initTable[string, string]()

proc argErr(cmd: string): string = 
  return "-ERR wrong number of arguments for '" & cmd & "' command\r\n"

proc err(cmd: varargs[string]): string = 
  return "-ERR unknown command `" & cmd[0] & "`, with args beginning with:\r\n"

proc ping(_: varargs[string]): string  =
  return "+PONG\r\n"

proc setData(cmd: varargs[string]): string  =
  if len(cmd) != 3: return argErr(cmd[0])
  echo cmd[1], cmd[2]
  database[cmd[1]] = cmd[2]
  return "+OK\r\n"

proc getData(cmd: varargs[string]): string =
  if len(cmd) != 2: return argErr(cmd[0])
  if database.haskey(cmd[1]):
    let val = database[cmd[1]]
    return "$" & len(val).intToStr & "\r\n" & val & "\r\n"
  return "$-1\r\n"

proc processCommand(cmd: varargs[string]): string =
  # if len(cmd) == 0: return "$0\r\n\r\n"
  case cmd[0]
  of "ping":
    return ping(cmd)
  of "set":
    return setData(cmd)
  of "get":
    return getData(cmd)
  else: 
    return err(cmd)


proc connectionHandler(client: Socket) {.thread.} =
  database["hoge"] = "fuga"
  echo database["hoge"] 
  defer: client.close()
  let line = client.recvLine()
  let n: int = line[1..^1].parseInt()
  var command: seq[string] = newSeq[string](n)
  for i in 0..n-1:
    let line = client.recvLine()
    command[i] = client.recvLine()

  client.send(processCommand(command))
  # connectionHandler(client)
    

proc handlerWrapping(server: Socket) {.async.} =
  var client: Socket = new(Socket)
  server.accept(client)
  clients.add(client)
  spawn connectionHandler(client)
  

proc serve() {.async.} =
  clients = @[]

  let server: Socket = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  # server.getFd.setBlocking(false)
  server.bindAddr(Port(6379))
  server.listen()
  while true:
    try:
      await handlerWrapping(server)
    except OSError:
      discard

asyncCheck serve()