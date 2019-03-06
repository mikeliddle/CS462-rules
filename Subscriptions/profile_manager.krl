ruleset profile_manager {
  meta{
    use module io.picolabs.twilio_v2 alias twilio
    use module io.picolabs.keys
        use module io.picolabs.twilio_v2 alias twilio
            with account_sid = keys:twilio{"account_sid"}
                  auth_token = keys:twilio{"auth_token"}
  }

  global{
    twilio_number = "4358506161"

    phone_number = function() {
        ent:sms_number.defaultsTo("8018336518")
    }
  }

  rule threshold_notifications {
    select when sensor threshold_violation

    pre {
        message = event:attr("message").defaultsTo("High Temperature");
    }

    every{
        twilio:send_sms(phone_number(), twilio_number, message);
    }
  }
}