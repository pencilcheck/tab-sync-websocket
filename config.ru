#\ -s thin

require 'faye/websocket'
require 'json'
$stdout.sync = true
Faye::WebSocket.load_adapter('thin')

$clients = {}

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, nil, {ping: 10000})

    ws.on :open do |event|
      p 'new client', ws.object_id
      $clients[ws.object_id] = ws
      ws.send({who: 'onopen', message: ws.object_id}.to_json)
    end

    ws.on :message do |event|
      data = JSON.parse(event.data)
      data = data.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

      p 'message from client', data
      if data[:dest_id] == 'setup'
        $clients[data[:message][1]] = $clients[data[:message][0]]
        $clients.delete(data[:message][0])
      else
        p 'non setup'
        unless (defined? data[:dest_id]).nil?
          p 'Unicast'
          $clients[data[:dest_id]].send({
            who: data[:src_id],
            message: data[:message]
          }.to_json)
        else
          p 'Broadcast'
          $clients.each {|id, client| client.send({
            who: data[:src_id],
            message: data[:message]
          }.to_json)}
        end
      end
    end

    ws.on :error do |event|
      p 'error client', event
    end

    ws.on :close do |event|
      p 'delete client', ws.object_id
      $clients.delete(ws)
      ws.send('Bye Bye')
      ws = nil
    end

    ws.rack_response
  end
end

run App
