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
        
        getProfile = function() {
          {
            "name": ent:getName(),
            "location": ent:getLocation(),
            "phone": ent:getPhoneNumber(),
            "threshold": ent:getTemperatureThreshold()
          }
        }
    }

    rule profile_changed {
        select when sensor profile_updated

        pre {
            location = event:attr("location").defaultsTo(false)
            username = event:attr("username").defaultsTo(false)
            phoneNumber = event:attr("phoneNumber").defaultsTo(false)
            threshold = event:attr("tempThreshold").defaultsTo(false)
            
            message = location && username && phoneNumber && threshold => "Profile Updated!" | "Missing Parameter"
            // threshold should be set, sms change
        }

        
        send_directive(message)

        always {
            raise profile event "attributes_updated"
              attributes {
                "location": location,
                "username": username,
                "phone": phoneNumber,
                "threshold": threshold
              } if (message == "Profile Updated!")
        }
    }
    
    rule attributes_changed {
      select when profile attributes_updated
      
      send_directive("Changing Attributes!")
      
      always {
        ent:temperature_threshold := event:attr("threshold");
        ent:username := event:attr("username");
        ent:location := event:attr("location");
        ent:phoneNumber := event:attr("phone");
      }
    }
}