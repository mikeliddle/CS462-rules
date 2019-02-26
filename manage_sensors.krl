ruleset manage_sensors {
  meta{  
    use module io.picolabs.wrangler alias wrangler
    use module temperature_store alias temps
    provides profiles, sensors, getTemperatures
    shares profiles, sensors, getTemperatures
  }

    global {
        threshold = 70
        rules = [
            "wovyn_base",
            "sensor_profile",
            "temperature_store",
            "io.picolabs.keys",
            "io.picolabs.twilio_v2",
            "io.picolabs.use_twilio_v2"
        ]
        
        profiles = function() {
          ent:picos
        }

        sensors = function() {
          ent:sensors
        }

        getTemperatures = function() {
            ent:sensors.map(function(x) {
                wrangler:skyQuery(x,"temperature_store","temperatures", []).klog();
            });
        }
    }

    rule create_sensor {
        select when sensor new_sensor

        pre {
            sensor_id = event:attr("sensor_id")
            name = event:attr("name")
            phone = event:attr("phone")
            location = event:attr("location")
            exists = ent:sensors >< sensor_id
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

    rule update_rules {
        select when wrangler new_child_created

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
            )
        }
        
        always {
          ent:sensors := ent:sensors.defaultsTo({}).put(sensor_id, eci);
        }
    }
    
    rule delete_sensor {
        select when sensor unneeded_sensor

        pre {
            sensor_id = event:attr("sensor_id")
        }

        send_directive("Removing Sensor");

        always {
            ent:sensors.delete(sensor_id);
            ent:picos.delete(sensor_id);

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
      }
    }
}