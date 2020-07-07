var system = require('system');
var page = require('webpage').create();

page.open(system.args[1], function() {
    	page.evaluate(function() {
        	window.scrollTo(0, window.document.getElementsByClassName("ytd-search")[0].scrollHeight);
    	});
    	window.setTimeout(function() {
        	console.log(page.content);
        	phantom.exit();
    	}, 500);

})
