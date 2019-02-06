ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        temperature_threshold = 60;

        temperatures = function() {
            ent:temperatures.defaultsTo([]);
        }

        threshold_violations = function() {
            ent:threshold_violations.defaultsTo([]);
        }

        inrange_temperatures = function() {
            ent:temperatures.defaultsTo([]).filter(
                    function(x){
                        x < temperature_threshold
                    });
        }
    }

    rule collect_temperature {
        select when wovyn new_temperature_reading

        pre {
            value = event:attr("genericThing").defaultsTo(false)
        }

        if value then
            send_directive("Collecting Temperature")

        fired {
            ent:temperatures := temperatures.append([event:attrs])
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        
        always {
            send_directive("Adding violation to list");
            ent:threshold_violations := threshold_violations.append([event:attrs]);
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        
        always {
            clear ent:temperatures;
            clear ent:threshold_violations;
        }
    }
}