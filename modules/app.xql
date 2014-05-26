xquery version "3.0";

module namespace app="http://jmmc.fr/apps/voar/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://jmmc.fr/apps/voar/config" at "config.xqm";

import module namespace jmmc-about="http://exist.jmmc.fr/jmmc-resources/about" at "/db/apps/jmmc-resources/content/jmmc-about.xql";
(: 
let $urls := data(collection("/db/apps/voar/registry")//metadata[key="home.page" or matches(key,"url","i") ]/value)

let $tests := for $url in $urls 
    return 
        try {
            let $res := httpclient:get($url, false(),<headers/>)
            return <test><url>{$url}</url></test>
        } catch * {
            <test><error>{$err:description}</error><url>{$url}</url></test>
    }


return <p>{count($tests//url)} tested urls, {count($tests//error)} error(s)</p> :)

declare function app:categories($node as node(), $model as map(*)){
    let $c := data(for $c in doc($config:app-root||"/registry/__index__.xml")//SampStubList/family/@category order by $c return $c)
    return map { "categories" := $c }
};

declare function app:category-checkbox($node as node(), $model as map(*), $category as xs:string*){
    let $cat := $model("category")
    return ( if($cat=$category) then attribute {"checked"} {"on"} else (), attribute {"value"} {$cat} ,  attribute {"type"} {"checkbox"}, attribute {"name"} {"category"}, $cat)
};

(: produce initial SampStub list with some filtering :)
declare function app:get-stubs() as node()* {    
    let $stubs := collection($config:app-root||"/registry")//SampStub
    let $families := doc($config:app-root||"/registry/__index__.xml")//SampStubList/family
    
    (: append to the stub list a category node and filter out appLauncherTester :)
    for $s in $stubs[@uid != "AppLauncherTester"]    
    order by $s/@uid  return
        element {name($s)} { $s/@*, element {"category"} {data($families[application=$s/@uid]/@category)}, $s/*}     
};

declare function app:search-stubs($category as xs:string*, $mtype as xs:string*, $description as xs:string*, $q as xs:string*, $qtype as xs:string?) {    

    let $stub-list := app:get-stubs()        
    let $stub-list := if(exists($mtype)) then for $s in $stub-list where some $m in $mtype satisfies matches(string-join($s/subscription,","),$m,"i") return $s else $stub-list
    let $stub-list := if(exists($description)) then for $s in $stub-list where some $d in $description satisfies matches($s/metadata[key="samp.description.text"]/value,$d,"i") return $s else $stub-list
    
    let $stub-list := if($q) then 
                        switch( $qtype )
                            case "name" return
                                $stub-list[metadata[key="samp.name"]/value[matches(.,$q,"i")]]                             
                            case "mtype" return                                
                                $stub-list[subscription[matches(.,$q,"i")]]
                            case "desc" return
                                $stub-list[metadata[key="samp.description.text"]/value[matches(.,$q,"i")]]                             
                            default return
                                (: $stub-list[subscription[matches(.,$q,"i")] or metadata[key="samp.description.text"]/value[matches(.,$q,"i")]]
                                :)
                                $stub-list[matches(.,$q,"i")]
                    else
                        $stub-list                 
        
    let $stub-list :=   if(exists($category)) then $stub-list[$category = category] else $stub-list    
    
    return $stub-list
};

declare function app:search($node as node(), $model as map(*), $category as xs:string*, $mtype as xs:string*, $description as xs:string*, $q as xs:string*, $qtype as xs:string?) {        
    let $stub-list := app:search-stubs( $category, $mtype, $description, $q, $qtype)        
    return
        map:new(($model,map { "stubs" := $stub-list , "info" := count($stub-list)||" stubs "||count($category)||" cats ("||string-join($category,",")}))
};

declare function app:display($node as node(), $model as map(*), $format as xs:string?) {    
    let $stubs := $model("stubs")
    return    
        if($format="json") then 
            app:displayJson($node, $model)
        else if($format="xml") then 
            app:displayXml($node, $model)
        else        
        for $stubl in $stubs
        let $family := $stubl/category
        group by $family
        order by $family
        return
        <div>
            <h2>{data($family)}</h2>
            <!-- {$model("info")} -->
            <table>
                <tr>
                    <td>
                        <ul>
                        {
                            for $stub in $stubl                      
                            let $app := data($stub/@uid)    
                            let $desc := data($stub//metadata[key="samp.description.text"]/value)
                            let $desc := if(string-length($desc)>80) then substring($desc, 1, 57)|| "..." else $desc
                            return <li><a href="app.html?app={$app}">{$app} : {$desc}</a></li>
                        }    
                        </ul>                            
                    </td>
                    <!--
                    <td>
                        {
                            let $stubs := collection("/db/apps/voar/registry/")//SampStub[.//metadata[matches(key,"samp.icon.url")]/value and .//metadata[matches(key,"samp.name")]/value=$family/application]
                            return
                            <table border="1">                              
                                <tr>
                                    {for $stub in $stubs return <td> <img src="{$stub//metadata[key='samp.icon.url']/value}"/></td>}
                                </tr>
                                <tr>
                                    {for $stub in $stubs return <td> <a href="app.html?app={$stub//metadata[key='samp.name']/value}">{$stub//metadata[key='samp.name']/value}</a> </td>}
                                </tr>
                            </table>
                        }
                    </td>
                    -->
            </tr>
            </table>
        </div>
};

declare function app:displayJson($node as node(), $model as map(*)) as xs:string {
let $stubs := $model("stubs")

let $jsonpCallback := request:get-parameter("jsonp", ())

(:
 : We can't extract directly samp stub elements because we need to 
 : <list>{collection($config:app-root)//SampStubList}{collection($config:app-root)//SampStub}</list>
 :)
let $list := <list>
    {
        for $app in $stubs
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
</list>
let $json := util:serialize($list, "method=json")

return if($jsonpCallback) then $jsonpCallback||"("||$json||")" else $json
};

declare function app:getJson() as xs:string {
    
let $category := request:get-parameter("category", ())
let $mtype := request:get-parameter("mtype", ())    
let $description := request:get-parameter("description", ())    
let $q := request:get-parameter("q", ())    
let $qtype := request:get-parameter("qtype", ())    
let $stubs := app:search-stubs( $category, $mtype,$description, $q, $qtype)

let $jsonpCallback := request:get-parameter("jsonp", ())

(:
 : We can't extract directly samp stub elements because we need to 
 : <list>{collection($config:app-root)//SampStubList}{collection($config:app-root)//SampStub}</list>
 :)
let $list := <list>
    {
        for $app in $stubs
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
</list>
let $json := util:serialize($list, "method=json")

return if($jsonpCallback) then $jsonpCallback||"("||$json||")" else $json
};


declare function app:displayXml($node as node(), $model as map(*)) as xs:string { 
    let $stubs := $model("stubs")
    let $list := <list>    { $stubs } </list>
    return serialize($list)
};


declare function app:filterMeta($str as xs:string*)
{
    if(matches($str,"://")) then
        <a href="{$str}">{$str}</a>
    else
        $str
};

declare function app:getApplicationDetail($node as node(), $model as map(*)) {
    let $app          := request:get-parameter("app",0)
    let $appDocument  := concat("/db/apps/voar/registry/", $app, ".xml")
    let $metadatas    := doc($appDocument)//SampStub/metadata
    let $capabilities := doc($appDocument)//SampStub/subscription
    return    
        <div>
            {
                let $sampIconUrl := $metadatas[matches(key,"samp.icon.url")]/value
                let $homePage := $metadatas[matches(key,"home.page")]/value
                return if ($sampIconUrl)
                then
                    if($homePage)
                    then
                        <a href="{$homePage}"><img style="float:right;" src="{$sampIconUrl}" alt="icon"/></a>
                    else
                        <img style="float:right;" src="{$sampIconUrl}" alt="icon"/>
                else ()
            }
            <h2>SAMP Metadata for '{$app}'</h2>
            <ul>
            {
                for $metadata in $metadatas
                return <li>{$metadata/key/text()} : {app:filterMeta($metadata/value/text())}</li>
            }    
            </ul>
            <h2>SAMP Capabilities for '{$app}'</h2>
            <ul>
            {
                for $capability in $capabilities[not(starts-with(., "samp."))]
                return <li>{$capability/text()}</li>
            }    
            </ul>
        </div>
};

declare variable $app:code :=<div>
    
    <!-- skip the following line if your page already integrates the jQuery library -->
    <script type="text/javascript" src="http://voar.jmmc.fr/api/jquery-1.11.1.min.js"/>
    
    <!-- define an ul element with uniq id -->
    <ul id="sampListByMtype"></ul>            
            
    <!-- load the main javascript and call functions over the previously defined ul -->
    <script type="text/javascript" src="http://voar.jmmc.fr/api/voar-0.0.1.js"/>
    <script type="text/javascript">
    
        <![CDATA[    $("#sampListByMtype").getSampAppList({'mtype':'table.load.votable'}) ]]>
        
    </script>
        
</div>;



declare function app:getEmbedderCode($node as node(), $model as map(*)) {
    $app:code
};

declare function app:getEmbedderSnippet($node as node(), $model as map(*)) {
        <figure>
            <div class="code" data-language="html" style="background: #555555">
            {
                serialize($app:code)
            }                
            </div>
            <figcaption>Javascript to include onto your web page</figcaption>        
        </figure>
};