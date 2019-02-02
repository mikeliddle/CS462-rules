ruleset wovyn_base {
    meta {
    }

    rule process_heartbeat {
        select when wovyn heartbeat

        pre {
            has_value = event:attr("genericThing").defaultsTo(false)
        }

        if has_value then             
            send_directive("Heartbeat!")
        
    }
}