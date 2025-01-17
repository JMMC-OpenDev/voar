xquery version "3.1";

module namespace app="http://jmmc.fr/apps/voar/templates";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";
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
    return map { "categories" : $c }
};

declare function app:category-checkbox($node as node(), $model as map(*), $category as xs:string*){
    let $cat := $model("category")
(:  return ( if($cat=$category) then attribute {"checked"} {"on"} else (), attribute {"value"} {$cat} ,  attribute {"type"} {"checkbox"}, attribute {"name"} {"category"}, $cat) :)
    return element {name($node)} {( if($cat=$category) then attribute {"checked"} {"on"} else (), attribute {"value"} {$cat} ,  attribute {"type"} {"checkbox"}, attribute {"name"} {"category"}, $cat)}
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
        map:merge(($model,map { "stubs" : $stub-list , "info" : count($stub-list)||" stubs "||count($category)||" cats ("||string-join($category,",")}))
};

declare function app:display($node as node(), $model as map(*), $format as xs:string?) {    
    let $stubs := $model("stubs")
    return    
        if($format="json") then 
            app:displayJson($node, $model)
        else if($format="xml") then 
            app:displayXml($node, $model)
        else        
        let $defaultTab := "Dock"
        let $variants := map{
        
        $defaultTab : <div>
            {
            for $stubl in $stubs
            let $family := $stubl/category
            group by $family
            order by $family
            return
                (
                    <h3>{data($family)}</h3>,
                    <ul class="list-inline">{
                    for $stub in $stubl                      
                    let $app := data($stub/@uid)    
                    let $jnlp-url := $stub//metadata[key="x-samp.jnlp.url"]/value
                    let $url := data(for $k in ("x-samp.webapp.url","home.page", "samp.documentation.url") return $stub//metadata[key=$k]/value)[1]
                    let $desc := data($stub//metadata[key="samp.description.text"]/value)
                    let $desc := if(string-length($desc)>80) then substring($desc, 1, 57)|| "..." else $desc
                    let $icon := "./registry/"||$app||".png" (: force local icon :)
                    return 
(:                        <div class="col-xs-6 col-md-3">:)
                            <li ><a href="{$url}"><img class="img-thumbnail" style="width: 80px; display: block;" src="{$icon}"/> </a>
                            { if ($jnlp-url) then  <a href="{$jnlp-url}"><em>javaws</em></a> else () }
                            <a href="app.html?app={$app}"><span class="pull-right glyphicon glyphicon-info-sign" aria-hidden="true"></span></a>
                            
                                
                            </li>
(:                        </div>:)
                    }</ul>
                )
            }
            </div>,
            "Table" : <div>
            <table class="table table-striped">
            <thead>
                <tr><th></th><th>App</th><th>Description</th><th>Affiliation</th></tr>
            </thead>
            {
            for $stubl in $stubs
            let $family := $stubl/category
            group by $family
            order by $family
            return
                (
                    <tr><th></th><th colspan="3">{data($family)}</th></tr>,
                    for $stub in $stubl                      
                    let $app := data($stub/@uid)    
                    let $desc := data($stub//metadata[key="samp.description.text"]/value)
                    let $desc := if(string-length($desc)>80) then substring($desc, 1, 57)|| "..." else $desc
                    let $icon := $stub//metadata[key='samp.icon.url']/value
                    let $icon := if($icon) then $icon else "./registry/"||$app||".png"
                    return 
                        <tr>
                            <td><img src="{$icon}" height="30px"/></td><td><a href="app.html?app={$app}">{$app}</a></td><td>{$desc}</td><td>{data($stub//metadata[key=("x-samp.affiliation.name", "author.affiliation")]/value)[1]} </td>
                        </tr>
                )
            }</table>
            </div>,
        "By capabilities (mtypes)" : 
            let $capabilities := sort(distinct-values($stubs//subscription[not(starts-with(., "samp."))]))
            let $ordered-stubs := for $stubl in $stubs[.//subscription[not(starts-with(., "samp."))]]
                let $family := $stubl/category
                group by $family
                order by $family
                return
                    $stubl
            return 
                <table class="table table-striped table-header-rotated">
                <thead>
                    <tr><th></th>{ for $stub in $ordered-stubs return <th class="rotate-45"><div><span>{data($stub/@uid)}</span></div></th>}</tr>
                </thead>
                {
                    for $c in $capabilities return
                        <tr>
                            <td>{$c}</td>
                            { for $stub in $ordered-stubs return <td>{if ( $c = $stub//subscription ) then "X" else () }</td>}
                        </tr>
                }</table>,
        "By metadata" : 
            let $metadata := sort(distinct-values($stubs//metadata/key))
            let $ordered-stubs := for $stubl in $stubs
                let $family := $stubl/category
                group by $family
                order by $family
                return
                    $stubl
            return 
                <table class="table table-striped table-header-rotated">
                <thead>
                    <tr><th></th>{ for $stub in $ordered-stubs return <th class="rotate-45"><div><span>{data($stub/@uid)}</span></div></th>}</tr>
                </thead>
                {
                    for $m in $metadata
                    return
                        <tr>
                            <td>{$m}</td>
                            { for $stub in $ordered-stubs return <td>{if ( $m = $stub//metadata/key ) then <a href="#" title="{$stub//metadata[key=$m]/value}">X</a> else () }</td>}
                        </tr>
                }</table>
            }
        
        return <div>
            <ul class="nav nav-tabs" role="tablist">
            {  for $k at $pos in map:keys($variants) return <li role="presentation" class="{('active')[$k=$defaultTab]}"><a href="#tab__{$pos}" aria-controls="home" role="tab" data-toggle="tab">{$k}</a></li>   }
            </ul>
            <div class="tab-content">{
                for $k at $pos in map:keys($variants) return <div role="tabpanel" class="tab-pane fade {('in active')[$k=$defaultTab]}" id="tab__{$pos}">{map:get($variants,$k)}</div>
            }</div>
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

let $json := serialize($list, map{"method":"json", "indent":true()})

return if($jsonpCallback) then $jsonpCallback||"("||$json||")" else $json
};

declare function app:getJson() as xs:string {
    
let $categories      := (request:get-parameter("category", ()), request:get-parameter("category[]", ()))
let $mtypes         := (request:get-parameter("mtype", ()), request:get-parameter("mtype[]", ()))
let $description := request:get-parameter("description", ())    
let $q := request:get-parameter("q", ())    
let $qtype := request:get-parameter("qtype", ())    
let $stubs         := app:search-stubs( $categories, $mtypes,$description, $q, $qtype)

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
let $json := serialize($list, map{ "method":"json", "indent":true()})

return if($jsonpCallback) then $jsonpCallback||"("||$json||")" else $json
};


declare function app:displayXml($node as node(), $model as map(*)) as xs:string { 
    let $stubs := $model("stubs")
    let $list := <list>    { $stubs } </list>
    return serialize($list, map{"indent":true()})
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
    <script type="text/javascript" src="https://voar.jmmc.fr/api/jquery-1.11.1.min.js"/>
    
    <!-- define an ul element with uniq id -->
    <ul id="sampListByMtype"></ul>            
            
    <!-- load the main javascript and call functions over the previously defined ul -->
    <script type="text/javascript" src="https://voar.jmmc.fr/api/voar-0.3.js"/>
    <script type="text/javascript">
    
        <![CDATA[    $("#sampListByMtype").appendAppList({'mtype':'table.load.votable'}) ]]>
        
    </script>
        
</div>;



declare function app:getEmbedderCode($node as node(), $model as map(*)) {
    $app:code
};

declare function app:getEmbedderSnippet($node as node(), $model as map(*)) {
        <figure>
            <div class="code" data-language="html" style="background: #555555">
            {
                serialize($app:code, map{"indent":true()})
            }                
            </div>
            <figcaption>Javascript to include onto your web page</figcaption>        
        </figure>
};
