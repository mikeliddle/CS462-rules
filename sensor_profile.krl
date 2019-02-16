ruleset sensor_profile {
    meta {
        provides getTemperatureThreshold, getName, getLocation, getPhoneNumber
        shares getTemperatureThreshold, getName, getLocation, getPhoneNumber
    }

    global {
        getTemperatureThreshold = function() {
            ent:temperature_threshold.defaultsTo(60)
        }

        getName = function() {
            ent:username.defaultsTo("Mike")
        }

        getLocation = function() {
            ent:location.defaultsTo("Home")
        }

        getPhoneNumber = function() {
            ent:phoneNumber.defaultsTo("8018336518")
        }
    }

    rule collect_temperature {
        select when sensor profile_updated

        pre {
            location = event:attr("location").defaultsTo(false)
            username = event:attr("username").defaultsTo(false)
            // threshold should be set, sms change
        }

        if value then
            send_directive("Collecting Temperature")

        fired {
            ent:temperatures := ent:temperatures.defaultsTo([]).append([event:attrs])
        }
    }
}