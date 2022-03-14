xquery version "3.0";

(: This script returns json or jsonp if jsonp parameter is given
 : Wikipedia: JSONP provides cross-domain access to an existing JSON API, by wrapping a JSON payload in a function call.
 :)
declare option exist:serialize "media-type=text/javascript";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";
import module namespace config="http://jmmc.fr/apps/voar/config" at "modules/config.xqm";

import module namespace app="http://jmmc.fr/apps/voar/templates" at "modules/app.xql";

app:getJson()