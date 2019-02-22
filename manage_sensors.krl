ruleset manage_sensors {
    meta {
        shares __testing
    }

    global {
        nameFromID = function(sensor_id) {
            "sensor " + sensor_id + " Pico"
        }

        __testing = { "events":  [ { "domain": "sensor", "type": "needed", "attrs": [ "sensor_id" ] } ] }

    }

    rule create_sensor {
        select when sensor new_sensor

        pre {
            sensor_id = event:attr("sensor_id")
            exists = ent:sensors >< sensor_id
            eci = meta:eci
        }
        
        if exists then
            send_directive("sensor exists", {"sensor_id": sensor_id})

        notfired {
            ent:sensors := ent:sensors.defaultsTo([]).union([sensor_id])
            raise wrangler event "child creation"
                attributes { "name": nameFromId(sensor_id), 
                             "color": "#ffff00",
                             "rids": ["wovyn_base", "sensor_profile", "temperature_store"] }
        }
    }

    rule update_rules {
        select when wrangler new_child_created

        pre {
            message = event:attrs()
        }
        
        send_directive(message)

    }
}