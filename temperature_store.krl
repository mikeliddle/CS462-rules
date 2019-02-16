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
            ent:threshold_violations.defaultsTo([]);
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
            ent:temperatures := ent:temperatures.defaultsTo([]).append([event:attrs])
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
}