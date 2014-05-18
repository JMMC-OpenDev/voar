xquery version "3.0";

(: This script returns json or jsonp if jsonp parameter is given
 : Wikipedia: JSONP provides cross-domain access to an existing JSON API, by wrapping a JSON payload in a function call.
 :)
declare option exist:serialize "media-type=text/javascript";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://jmmc.fr/apps/voar/config" at "modules/config.xqm";


let $jsonpCallback := request:get-parameter("jsonp", ())

(:
 : We can't extract directly samp stub elements because we need to 
 : <list>{collection($config:app-root)//SampStubList}{collection($config:app-root)//SampStub}</list>
 :)
let $list := <list>
    {
        for $app in collection($config:app-root||"/registry")//SampStub
        order by $app/metadata[key="samp.name"]/value
        return <SampApplication>
            {
                for $meta in $app//metadata                    
                    let $name := translate(tokenize($meta/key/text(), "samp.")[last()],".","_")
                    order by $name
                    return element {$name} {$meta/value/text()}
            }
        </SampApplication>    
    }
    {collection($config:app-root)//SampStubList/family}
</list>
let $json := util:serialize($list, "method=json")

return if($jsonpCallback) then $jsonpCallback||"("||$json||")" else $json