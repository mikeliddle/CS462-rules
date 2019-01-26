ruleset io.picolabs.twilio_v2 {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms,
        messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    messages = defaction(to = null, from = null) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      
      query = to && from => {"To": to, "From": from} | to => {"To": to} | from => {"From": from} | null 
      
      http:get(base_url + "Messages.json",
                 qs = query,
                      parseJSON = true) setting(returnValue)
      returns
      {
        "result": returnValue
      } 
    }
  }
}