#!/usr/bin/env groovy

@Grab('org.noggit:noggit:0.7')
import org.noggit.JSONParser
import org.noggit.ObjectBuilder

args.each { filename ->
    new File(filename).withInputStream { s->
        def r = new InputStreamReader(s)
        def p = new JSONParser(r)
        def b = new ObjectBuilder(p)
        try {
            while( ( o = b.getObject())  != null ) {
                println o
            }
        } catch( JSONParser.ParseException px ) {
            if (s.available() == 0 ) {
                // a-ok
            } else {
                px.printStackTrace(System.err)
            }
        } 
    }
}

