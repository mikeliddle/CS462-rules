ruleset wovyn_base {
    meta {
        use module io.picolabs.keys
        use module io.picolabs.twilio_v2 alias twilio
            with account_sid = keys:twilio{"account_sid"}
                  auth_token = keys:twilio{"auth_token"}
    }

    global {
        temperature_threshold = 72
        twilio_number = "4358506161"
        my_number = "8018336518"
    }

    rule process_heartbeat {
        select when wovyn heartbeat

        pre {
            value = event:attr("genericThing").defaultsTo(false)


        }

        if has_value then
            send_directive("Heartbeat!")

        fired {
          raise wovyn event "new_temperature_reading"
            attributes {"temperature": eventattrs["genericThing"]["data"]["temperature"][0]["temperatureF"], "timestamp": time:now()}
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading

        pre {
            temp = event:attr("temperature")
        }

        if temp > temperature_threshold then
            send_directive("high temperature")

        fired {
            raise wovyn event "threshold_violation"
                attributes(eventattrs)
        }
        else {
            send_directive("normal temperature")
        }
    }

    rule threshold_notifications {
        select when wovyn threshold_violation

        twilio:send_sms(my_number,
                        twilio_number,
                        "High Temperature"
                       )
        fired {
            send_directive("sent sms")
        }
    }
}