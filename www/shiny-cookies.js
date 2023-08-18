// script.js
// https://book.javascript-for-r.com/shiny-cookies.html
function getCookies(){
  var res = Cookies.get();
  Shiny.setInputValue('cookies', res);
}

Shiny.addCustomMessageHandler("get_element_by_id", function(msg){
  var svg = document.getElementsByClassName("mermaid")[0].innerHTML;
  Shiny.setInputValue(msg, [String(svg), Math.random()]);
})

Shiny.addCustomMessageHandler('cookie-set', function(msg){
  Cookies.set(msg.name, msg.value, { expires: msg.expiry });
  getCookies();
})

Shiny.addCustomMessageHandler('cookie-remove', function(msg){
  Cookies.remove(msg.name);
  getCookies();
})

$(document).on('shiny:connected', function(ev){
  getCookies();
})

