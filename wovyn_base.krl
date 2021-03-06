ruleset wovyn_base {
    meta {
        use module sensor_profile
        use module io.picolabs.keys
        use module io.picolabs.twilio_v2 alias twilio
            with account_sid = keys:twilio{"account_sid"}
                  auth_token = keys:twilio{"auth_token"}
    }

    global {
        twilio_number = "4358506161"
    }

    rule process_heartbeat {
        select when wovyn heartbeat

        pre {
            value = event:attr("genericThing").defaultsTo(false)
        }

        if value then
            send_directive("Heartbeat!")

        fired {
          raise wovyn event "new_temperature_reading"
            attributes {"temperature": value["data"]["temperature"][0]["temperatureF"], "timestamp": time:now()}
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading

        pre {
            temp = event:attr("temperature")
            message = temp <= sensor_profile:getTemperatureThreshold() => "Normal Temperature" | "High Temperature"
        }
            
        send_directive(message)

        always {
          raise wovyn event "threshold_violation"
            attributes event:attrs if (temp > sensor_profile:getTemperatureThreshold());
        }
    }

    rule threshold_notifications {
        select when wovyn threshold_violation

        every {
          twilio:send_sms(sensor_profile:getPhoneNumber(),
                          twilio_number,
                          "High Temperature"
                         );
          send_directive("sent sms to " + sensor_profile:getPhoneNumber());
        }
    }
}