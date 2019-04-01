ruleset sensor_gossip {
  meta {
    use module temperature_store
    use module sensor_profile
    use module io.picolabs.subscription alias subscriptions
  }

  global {
    getPeer = function() {
      available_peers = ent:peers.defaultsTo({}).filter(function(peer_value,peer_id) {
        adjusted_messages = ent:messages.defaultsTo({}).filter(function(origin_group, origin_id) {
          message_id = ent:peers{[peer_id,"messages",origin_id]};
          
          origin_group.keys().all(function(x) {x <= message_id});
        });
        
        length(adjusted_messages) > 0;
      });
      
      peer_count = length(available_peers.keys());
      rand_index = random:integer(0,peer_count);
      
      peer_index = available_peers.keys()[rand_index];
      
      available_peers{peer_index};
    }

    getMessage = function(peer) {
      
    }
  }

  rule new_gossip {
    select when gossip new_message

    pre {
      ids = event:attr("MessageID").split(re#:#)
      origin_id = ids[0]
      message_id = math:int(ids[1])
      message = event:attr("Message")

      origin_group = ent:messages.get(origin_id).defaultsTo({})
      updated_messages = origin_group.put(message_id, message)
    }

    if ent:messages{origin_id}.defaultsTo(False) && message_id - 1 != ent:messages{origin_id} then
      send_directive("Not adding Message")

    notfired {
      ent:messages{origin_id} := updated_messages
    }
  }

  rule gossip_heartbeat {
    select when gossip heartbeat

    pre {
      current_peer = getPeer()
      peer_entity = ent:peers{current_peer{"id"}}.defaultsTo({})
      message = getMessage(current_peer)
      peer_subscription = subscriptions:established("Tx_role", "peer").filter(function(x) {
        x{"Id"} == current_peer{"id"}
      })[0]
    }

    if message then
      event:send({
        "eci": "",
        "eid": "",
        "domain": "gossip",
        "type": "new_message",
        "attrs": {

        }
      })

    fired {
      ent:peers{[current_peer{"id"},"messages"]} := current_peer{"messages"}.set(message{"origin_id"}, message{"message_id"})
    }
  }
  
  rule new_peer {
    select when sensor new_peer

    pre {
      peer_id = event:attr("eci")
      peer_name = event:attr("sensor_name")
      host = event:attr("host")
    }

    send_directive("received a new peer!")

    always {
      ent:peers := ent:peers.defaultsTo({}).put(peer_id, {
        "id": peer_id,
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