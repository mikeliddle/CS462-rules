ruleset manage_sensors {
  meta{  
    use module io.picolabs.wrangler alias wrangler
    use module temperature_store alias temps
    use module io.picolabs.subscription alias subscriptions
    provides profiles, sensors, getTemperatures, getReports
    shares profiles, sensors, getTemperatures, getReports
  }

    global {
        threshold = 70
        rules = [
            "wovyn_base",
            "sensor_profile",
            "temperature_store",
            "io.picolabs.keys",
            "io.picolabs.twilio_v2",
            "io.picolabs.use_twilio_v2",
            "auto_accept"
        ]
        
        profiles = function() {
          ent:picos
        }

        sensors = function() {
          ent:sensors
        }

        getTemperatures = function() {
          subscriptions:established("Tx_role", "sensor").map(function(x) {
                {}.put(ent:sensors{x{"Id"}}, wrangler:skyQuery(x{"Tx"},"temperature_store","temperatures", {}, x{"Tx_host"}));
            });
        }

        getReports = function() {
          recent_keys = ent:reports.defaultsTo({}).keys().sort(function(a, b) {
                            a > b  => -1 |
                            a == b =>  0 |
                                      1
                          }).klog();
          
          count = length(recent_keys).klog();
          
          limit = (count > 5) => 4 | count - 1;
          limit.klog();
          
          recent_keys = recent_keys.slice(limit).klog();
          
          recent_keys.map(function(x) {
            {}.put(x,ent:reports.get(x).klog());
          })
          // ent:reports
        }
    }

    rule new_sensor {
        select when sensor new_sensor

        pre {
            sensor_id = event:attr("sensor_id")
            name = event:attr("name")
            phone = event:attr("phone")
            location = event:attr("location")
            exists = ent:profiles >< sensor_id
        }
        
        if exists then
            send_directive("sensor exists", {"sensor_id": sensor_id})

        notfired {
            ent:picos := ent:picos.defaultsTo({}).put(sensor_id, {"username": name, 
                                                          "phoneNumber": phone, 
                                                          "tempThreshold": threshold, 
                                                          "location": location});
            raise wrangler event "child_creation"
                attributes { "name": sensor_id,
                             "color": "#ffff00",
                             "rids": rules };
        }
    }

    rule update_child_profile {
        select when wrangler child_initialized

        pre {
            options = event:attrs
            sensor_id = event:attr("name")
            profile = ent:picos.get(sensor_id)
            eci = event:attr("eci")
        }
        
        every{
            send_directive("updating", options);
            event:send(
                {
                    "eci": eci, "eid": "eid",
                    "domain": "sensor", "type": "profile_updated",
                    "attrs": profile
                }
            );
        }
        
        always {
          raise sensor event "subscribe"
            attributes {
                "eci": eci,
                "sensor_name": sensor_id,
                "host": meta:host
            }
        }
    }
    
    rule sensor_ent_add {
      select when wrangler subscription_added
      pre{
        name = event:attr("name")
        eci = event:attr("Id")
        rx = event:attr("Rx")
      }

      send_directive("received subscription", event:attrs)

      always {
          ent:sensors := ent:sensors.defaultsTo({}).put(eci,name);
          ent:picos{name} := ent:picos{name}.put("Rx",rx);
      }
    }

    rule sensor_subscribe {
        select when sensor subscribe

        pre {
            sensor_eci = event:attr("eci")
            sensor_name = event:attr("sensor_name")
            host = event:attr("host")
        }
        
        send_directive("subscribing sensor")

        always {
            raise wrangler event "subscription" attributes {
                "name": sensor_name,
                "Rx_role": "owner",
                "Tx_role": "sensor",
                "Tx_host": host,
                "channel_type": "subscription",
                "wellKnown_Tx": sensor_eci
            }
        }
    }
    
    rule delete_sensor {
        select when sensor unneeded_sensor

        pre {
          sensor_id = event:attr("sensor_id")
        }

        send_directive("Removing Sensor")

        always {
          raise wrangler  event "subscription_cancellation" attributes {
            "Rx": ent:picos{sensor_id}{"Rx"}
          };
          
          ent:sensors := ent:sensors.delete(ent:picos{sensor_id}{"Rx"});
          ent:picos := ent:picos.delete(sensor_id);

          raise wrangler event "child_deletion"
            attributes {"name": sensor_id};
        }
    }
    
    rule clear_ents {
      select when sensor clear_ents
      
      send_directive("clearing variables")
      
      always{
        ent:picos := {};
        ent:sensors := {};
        ent:reports := {};
      }
    }

    rule get_temperatures {
        select when manager temperatures_needed
          foreach subscriptions:established("Tx_role", "sensor") setting (sensor)

        event:send({
          "eci": sensor{"Tx"},
          "eid": ent:correlation_id.defaultsTo(0),
          "domain": "sensor",
          "type": "report_needed",
          "attrs": {
              "report_id": ent:correlation_id.defaultsTo(0),
              "host": meta:host,
              "eci": meta:eci
          }
        }, sensor{"Tx_host"})

        always {
          ent:reports := ent:reports.defaultsTo({}).put(ent:correlation_id.defaultsTo(0), {
            "temperature_sensors": length(subscriptions:established("Tx_role", "sensor"))
          }) on final;
          ent:correlation_id := ent:correlation_id.defaultsTo(0) + 1 on final;
        }
    }

    rule assemble_report {
        select when manager report_ready

        pre {
          report_id = event:attr("report_id");
          current_report = ent:reports.defaultsTo({}).get(report_id).defaultsTo({});
          temperatures = event:attr("temperatures");
          current_report{"temperatures"} = current_report{"temperatures"}.defaultsTo([]).append(temperatures);
          current_report{"responding"} = current_report{"responding"}.defaultsTo(0) + 1;
          current_report{"timestamp"} = time:now();
        }
      
        noop()

        always {
            ent:reports{report_id} := current_report
        }
    }
}