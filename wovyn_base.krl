ruleset wovyn_base {
    meta {
    }

    rule process_heartbeat {
        select when wovyn heartbeat
        send_directive("Heartbeat!")
    }
}