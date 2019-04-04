ruleset sensor_gossip {
  meta {
    use module temperature_store
    use module sensor_profile
    use module io.picolabs.subscription alias subscriptions
    provides getMessages, getPeers, getSeen
    shares getMessages, getPeers, getSeen
  }

  global {
    getMessages = function() {
      ent:messages.defaultsTo({})
    }
    
    getPeers = function() {
      ent:peers.defaultsTo({})
    }

    getSeen = function() {
      ent:seen.defaultsTo({})
    }

    getPeer = function() {
      available_peers = ent:peers.defaultsTo({}).filter(function(peer_value,peer_id) {
        adjusted_messages = ent:messages.defaultsTo({}).filter(function(origin_group, origin_id) {
          message_id = ent:peers{[peer_id,"messages",origin_id]}.klog("message_id");
          
          origin_group.keys().any(function(x) {x > message_id}).klog("origin_groups");
        });
        
        length(adjusted_messages) != 0;
      });
      
      peer_count = length(available_peers.keys()) - 1;
      rand_index = random:integer(0,peer_count).klog("rand_index");
      
      peer_index = available_peers.keys()[rand_index].klog("peer_index");
      
      available_peers{peer_index}.klog("peer");
    }

    getAnyPeer = function() {
      peer_count = length(subscriptions:established("Tx_role", "peer")) - 1;
      rand_index = random:integer(peer_count).klog("peer_index");
      subscriptions:established("Tx_role", "peer").klog("peers")[rand_index].klog("peer");
    }

    getMessage = function(peer) {
      available_groups = ent:messages.defaultsTo({}).klog("messages").filter(function(origin_group, origin_id) {
        current_message_id = peer{["messages", origin_id]}.defaultsTo(false);
        messages = origin_group.keys().klog("message_keys");
        last_message = messages[length(messages) - 1];
        
        test = current_message_id => (current_message_id < last_message) | true;
        test.klog()
      });
      
      rand_index = random:integer(0,length(available_groups.keys()) - 1).klog("rand_index");
      group_index = available_groups.keys()[rand_index].klog("group_index");
      
      message_index = peer{["messages", group_index]};
      message_index = message_index => (math:int(message_index) + 1).as("String") | "1";
      
      {
        "MessageId": group_index + ":" + message_index,
        "Message": ent:messages{[group_index, message_index.klog("MessageId")]}.klog("returns")
      }
    }
  }
  
  rule message_available {
    select when wovyn new_temperature_reading
    
    pre {
      origin_id = meta:picoId
      temp = event:attr("temperature").defaultsTo(false)
      time = time:now()
      message_group = ent:messages{origin_id}.defaultsTo({})
      message_id = math:int(ent:seen{origin_id}.defaultsTo(0)) + 1
    }
    
    if temp then 
      send_directive("temperature received")
      
    fired {
      ent:messages{origin_id} := message_group.put(message_id, {
        "temperature": temp,
        "timestamp": time
      });
      ent:seen{origin_id} := message_id;
    }
  }

  rule new_seen {
    select when gossip seen where ent:process.defaultsTo(true)

    pre {
      my_eci = meta:eci
      their_name = subscriptions:established("Rx", my_eci)[0].klog("peer"){"Tx"}
      new_seen = event:attrs
    }

    send_directive("received seen", new_seen)

    always {
      ent:peers{[their_name, "messages"]} := new_seen
    }
  }

  rule new_gossip {
    select when gossip rumor where ent:process.defaultsTo(true)

    pre {
      ids = event:attr("MessageId")
      id_array = ids.split(re#:#)
      origin_id = id_array[0]
      message_id = math:int(id_array[1])
      message = event:attr("Message")

      origin_group = ent:messages.get(origin_id).defaultsTo({})
      updated_messages = origin_group.put(message_id, message)
    }

    if origin_group != {} && message_id - 1 != math:int(ent:seen{origin_id}) then
      send_directive("Not adding Message", {"ids": ids})
 
    notfired {
      ent:messages := ent:messages.defaultsTo({}).set(origin_id, updated_messages);
      ent:seen{origin_id} := message_id;
    }
  }

  rule gossip_heartbeat {
    select when gossip heartbeat where ent:process.defaultsTo(true)

    pre {
      seen = random:integer(0,1) == 1
    }

    if seen then
      send_directive("seen_message");

    fired {
      raise gossip event "seen_requested" attributes event:attrs
    }
    else {
      raise gossip event "rumor_requested" attributes event:attrs
    }
  }

  rule send_rumor {
    select when gossip rumor_requested where ent:process.defaultsTo(true)

    pre {
      current_peer = getPeer()
      peer_entity = ent:peers{current_peer{"id"}}.defaultsTo({})
      message = getMessage(current_peer)
      peer_subscription = subscriptions:established("Tx_role", "peer").filter(function(x) {
        x{"Tx"}.klog("tx") == current_peer{"id"}.klog("peerId")
      })[0].klog("subscription")
    }

    every{
      send_directive("peer", peer_subscription);
      event:send({
        "eci": peer_subscription{"Tx"},
        "eid": "none",
        "domain": "gossip",
        "type": "rumor",
        "attrs": message
      });
    }
  }

  rule send_seen {
    select when gossip seen_requested where ent:process.defaultsTo(true)

    pre {
      peer_subscription = getAnyPeer()
      my_seen = ent:seen.defaultsTo({})
    }

    every {
      send_directive("seen", my_seen);
      event:send({
          "eci": peer_subscription{"Tx"},
          "eid": "none",
          "domain": "gossip",
          "type": "seen",
          "attrs": my_seen
        });
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
        "name": peer_id,
        "Rx_role": "peer",
        "Tx_role": "peer",
        "Tx_host": host,
        "channel_type": "subscription",
        "wellKnown_Tx": peer_id
      }
    }
  }

  rule update_peer {
    select when wrangler subscription_added

    pre {
      peer_id = event:attr("name").klog("name")
      new_id = event:attr("Tx").klog("tx")
    }

    send_directive("updating peer")

    fired {
      ent:peers := ent:peers.delete(peer_id);
      ent:peers := ent:peers.defaultsTo({}).set(new_id, {
        "id": new_id,
        "messages": {}
      });
    }
  }

  rule schedule_heartbeat {
    select when system online or wrangler ruleset_added or gossip heartbeat

    send_directive("Scheduled Heartbeat!")

    always {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n.defaultsTo("10")})
    }
  }
  
  rule status_changed {
    select when gossip process
    
    pre {
      status = event:attr("status")
      new_status = status == "on" => true | status != "off"
    }
    
    send_directive("updated status")
    
    fired {
      ent:process := new_status
    }
  }

  rule update_n {
    select when gossip interval_changed

    pre { 
      new_n = event:attr("n").defaultsTo(false)
    }

    if new_n then
      send_directive("updating n", new_n)

    fired {
      ent:n := new_n
    }
  }
}