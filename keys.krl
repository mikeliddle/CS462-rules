ruleset io.picolabs.keys {
  meta {
    key twilio {
          "account_sid": "<your account SID here>", 
          "auth_token" : "<your auth token here>"
    }
    provides keys twilio to io.picolabs.use_twilio_v2
  }
}