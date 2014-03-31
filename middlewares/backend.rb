require 'faye/websocket'
require 'json'
$stdout.sync = true

def symbolize_keys(hash)
  hash.inject({}){|result, (key, value)|
    new_key = case key
              when String then key.to_sym
              else key
              end
    new_value = case value
                when Hash then symbolize_keys(value)
                else value
                end
    result[new_key] = new_value
    result
  }
end

class Backend
  def initialize(app)
    @clients = {}
    @app = app
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, {ping: 15}) # secs

      ws.on :open do |event|
        p "open connection #{ws.object_id}"
        @clients[ws.object_id] = ws
        ws.send({type: 'onopen', payload: ws.object_id}.to_json)
      end

      ws.on :message do |event|
        data = symbolize_keys(JSON.parse(event.data))
        p "on message #{data}"

        if data[:type] == 'setup'
          @clients[data[:payload][1]] = @clients[data[:payload][0]]
          @clients[data[:payload][0]] = nil
        else
          @clients[data[:dest_id]].send(data.to_json) if @clients[data[:dest_id]]
        end
      end

      ws.on :error do |event|
        p 'error client', event
      end

      ws.on :close do |event|
        p "close connection #{ws.object_id}"
        @clients.delete(ws)
        ws.send('Bye Bye')
        ws = nil
      end

      ws.rack_response
    end
  end
end
