/* 
  API v-0.0.1 of voar
*/

(function($){
    $.fn.getSampAppList = function(params){
        return this.each(function(){                        
            var items = [];
            var ulEl = $(this);
            $.getJSON(
                'http://voar.jmmc.fr/json.xql?jsonp=?',params
                ).done(
                    function(data) {
                        $.each(data.SampApplication, function(i, f) {
                            var li = "<li><a href='"+  f.jnlp_url 
                            + "' info='" +f.description_text 
                            + "'><img src='"+f.icon_url
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