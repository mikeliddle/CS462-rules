ruleset temperature_store {
    meta {
        use module sensor_profile
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        temperatures = function() {
            ent:temperatures.defaultsTo([]);
        }

        threshold_violations = function() {
            ent:temperatures.defaultsTo([]).filter(
                function(x) {
                    x["temperature"] > sensor_profile:getTemperatureThreshold()
                }
            );
        }

        inrange_temperatures = function() {
            ent:temperatures.defaultsTo([]).filter(
                    function(x){
                        x["temperature"] < sensor_profile:getTemperatureThreshold()
                    });
        }
    }

    rule collect_temperature {
        select when wovyn new_temperature_reading

        pre {
            value = event:attr("temperature").defaultsTo(false)
        }

        if value then
            send_directive("Collecting Temperature")

        fired {
            ent:temperatures := ent:temperatures.defaultsTo([]).append([{
              "temperature": event:attr("temperature"),
              "timestamp": event:attr("timestamp")
            }])
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        
        send_directive("Adding violation to list")

        always {
            ent:threshold_violations := ent:threshold_violations.defaultsTo([]).append([event:attrs])
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        send_directive("clearing entity variables.")
        always {
            clear ent:temperatures;
            clear ent:threshold_violations;
        }
    }

    rule prepare_report {
        select when sensor report_needed

        pre {
            return_host = event:attr("host")
            report_id = event:attr("report_id")
            eci = event:attr("eci")
        }
        
        event:send({
              "eci": eci,
              "eid": ent:correlation_id.defaultsTo(0),
              "domain": "manager",
              "type": "report_ready",
              "attrs": {
                "report_id": report_id,
                "temperatures": temperatures()
              }
          }, return_host)
    }
}