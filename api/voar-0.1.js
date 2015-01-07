/* 
  API v-0.1 of voar
*/

(function($){
    $.fn.appendAppList = function(params){
        return this.each(function(){                        
            var items = [];
            var ulEl = $(this);
            $.getJSON(
                'http://voar.jmmc.fr/json.xql?jsonp=?',params
                ).done(
                    function(data) {
                        $.each(data.SampApplication, function(i, f) {
                            // check to prepare urls or backup ones if not provided
                            var url=f.jnlp_url;
                            var a_target;
                            var icon_url=f.icon_url;
                            
                            if( url === undefined ) {                                
                                a_target=" target='_blank'";
                                if( f.home_page !== undefined ){
                                    url=f.home_page;                            
                                }else if( f.documentation_url !== undefined ){
                                    url=f.documentation_url;
                                }else{
                                    url="http://ivoa.net/astronomers/applications.html";
                                }
                            }
                            
                            if( icon_url === undefined ) { 
                                icon_url="http://voar.jmmc.fr/registry/"+f.name+".png"
                            }                            
                            
                            var li = "<li>"
                            + "<a " + " href='" +  url + "' info='" +f.description_text 
                            + "' " + a_target + "><img src='"+icon_url
                            +"' width='30' style='vertical-align:middle;'/>&#160;"
                            + f.name + "</a></li>";
                            items.push(li);
                        });
                        ulEl.append(items.join(""));
                    }                    
                ).fail(
                    function() {
                        ulEl.append("<li>can't retrieve data :(</li>");
                    }
                );
            });                        
    };
})(jQuery);