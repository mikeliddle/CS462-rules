ruleset JournalApp {
  meta {
    shares getEntries
  } 
  
  global {
    myName = "Mike"
    
    getEntries = function() {
      myBinding = "hello";
      ent:entries.defaultsTo([])
    }
  }
  
  /*
  {
    "text": <string>,
    ...
  }
  */
  
  rule createEntry {
    //sel when  <domain> <type>
    select when journal new_entry
    pre {
      // precomputation, optional
      text = event:attr("text")
      currentTime = time:now()
      
      newEntry = {
        "text": text,
        "time": currentTime
      }
    }
    // js truthy checks null and empty
    if text then
      send_directive("Creating new entry!")
    fired {
      // postlude if text was true, we will run.
      // notfired exists as an antonym to fired.
      // entries is created but it doesn't know to what... defaultsTo does that.
      ent:entries := getEntries.append([newEntry])
      // the above means entries is mutable, not a binding.
    } else {
      // else block to fired ie. not text.
      raise journal event text_failed
        attributes {}
    }
  }
  
  rule trimEntries {
    select when journal new_entry where getEntries().length() > 4
    send_directive("trimming events")
    always {
      ent:entries := getEntries().tail()
    }
  }
  
  rule clearEntry {
    select when journal clear_entries_requested
    send_directive("Clearing Entries!")
    always{
      clear ent:entries 
    }
  }
}
