ruleset sensor_gossip {
  meta {
    use module temperature_store
    use module sensor_profile
  }

  global {
    getPeer = function() {

    }

    getMessage = function(peer) {

    }
  }

  rule new_gossip {
    select when gossip new_message

    pre {
      ids = event:attr("MessageID").split(re#:#)
      origin_id = ids[0]
      message_id = ids[1]
      message = event:attrs
    }

    if origin_id >< ent:messages.defaultsTo({}) 
        && message_id - 1 != ent:messages.get(origin_id) then
      send_directive("Not adding Message")

    notfired {
      ent:messages := ent:messages.defaultsTo({}).put(origin_id, message_id)
    }
  }

  rule gossip_heartbeat {
    select when gossip heartbeat

    pre {
      current_peer = getPeer()
      peer_entity = ent:peers{current_peer{"id"}}.defaultsTo({})
      message = getMessage(current_peer)
    }

    if message then
      send_directive("sending message to peer!")

    fired {
      ent:peers{current_peer{"id"}} := peer_entity.set(message{"origin_id"}, message{"message_id"});
      raise gossip event "new_message" attributes message
    }
  }
  
  rule new_peer {
    select when sensor new_peer

    pre {
      peer_id = event:attr("id")
      peer_name = event:attr("sensor_name")
      host = event:attr("host")
    }

    send_directive("received a new peer!")

    always {
      ent:peers := ent:peers.defaultsTo({}).put(peer_id, {
        "messages": {}
      });

      raise wrangler event "subscription" attributes {
        "name": peer_name,
        "Rx_role": "peer",
        "Tx_role": "peer",
        "Tx_host": host,
        "channel_type": "subscription",
        "wellKnown_Tx": peer_id
      }
    }
  }
}