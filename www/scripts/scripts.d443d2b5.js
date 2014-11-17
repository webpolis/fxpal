"use strict";window.onerror=function(a,b,c){return console.log("Caught[via window.onerror]: "+a+" from "+b+":"+c),!0},window.addEventListener("error",function(a){console.log("Caught[via error event]:  "+a.message+" from "+a.filename+":"+a.lineno),console.log(a),a.preventDefault()}),angular.module("aifxApp",["ngAnimate","ngCookies","ngResource","ngRoute","ngSanitize","ngTouch","ionic","ngTable","highcharts-ng","timer","aifxApp.services"]).config(["$stateProvider","$urlRouterProvider","$httpProvider",function(a,b,c){a.state("app",{url:"/app",templateUrl:"views/menu.html"}).state("app.main",{url:"/main",views:{menuContent:{templateUrl:"views/main.html",controller:"analyticsController"}}}).state("app.cross",{url:"/cross/:cross",views:{menuContent:{templateUrl:"views/cross.html",controller:"analyticsController"}}}).state("app.chart",{url:"/cross/:cross/chart",views:{menuContent:{templateUrl:"views/chart.html",controller:"analyticsController"}}}).state("app.portfolio",{url:"/portfolio",views:{menuContent:{templateUrl:"views/portfolio.html",controller:"portfolioController"}}}).state("app.about",{url:"/about",views:{menuContent:{templateUrl:"views/about.html"}}}),b.otherwise("/app/main"),c.interceptors.push(["$q","log",function(a,b){return{request:function(a){return b.spinner(),a},requestError:function(c){return b.spinner(!0),a.reject(c)},response:function(a){return b.spinner(!0),a},responseError:function(c){return b.spinner(!0),a.reject(c)}}}]),c.defaults.useXDomain=!0,c.defaults.headers.common={Connection:"Keep-Alive","Accept-Encoding":"gzip, deflate"},c.defaults.headers.post={Accept:"application/json, text/plain, */*"},c.defaults.headers.put={"Content-Type":"application/json"},c.defaults.headers.patch={}}]);var PhoneGapInit=function(){this.boot=function(){angular.bootstrap(document,["aifxApp"])},void 0!==window.phonegap?(document.addEventListener("deviceready",function(){this.boot()}),document.addEventListener("offline",function(){alert("Please check your internet connection")},!1)):this.boot()};angular.element(document).ready(function(){new PhoneGapInit}),angular.module("aifxApp").controller("appController",["$scope","$ionicSideMenuDelegate","$rootScope","utils","$state","api","$location",function(a,b,c,d,e,f,g){a.now=new Date,a.utils=d,a.state=e,a.api=f,a.data={currencies:null,multiset:{columns:null,data:null},cross:{columns:null,data:null},crosses:null,patterns:null},a.selected={cross1:null,cross2:null,currency1:null,currency2:null,cross:null,portfolio:null,patterns:{},granularity:null,volatility:null,currencyForce:null,strength:null,correlation:{markets:null,events:null},events:null},a.rootScope=c,a.config={appName:"qfx.club",logoSmall:'<img src="images/logo-s.png" />',token:"pWGUEdRoPxqEdp66WRYv",urls:{api:"http://qfx.club:9999/api/",cross:"http://www.quandl.com/api/v1/datasets/CURRFX/{{cross}}.json?trim_start={{startDate}}&trim_end={{endDate}}&collapse=daily&auth_token={{token}}",multiset:"http://quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&trim_start={{startDate}}&auth_token={{token}}",cpi:"http://quandl.com/api/v1/multisets.json?columns=&rows=10",rate:"https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20%3D%20%22{{cross}}%22&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=",candlestick:"http://api-fxpractice.oanda.com/v1/candles?instrument={{cross1}}_{{cross2}}&count={{count}}&candleFormat=midpoint&granularity={{period}}&weeklyAlignment=Monday",dailyChange:"http://www.quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=daily&auth_token={{token}}&rows=1&transformation=rdiff&rows=4",weeklyChange:"http://www.quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=weekly&auth_token={{token}}&rows=1&transformation=rdiff&rows=4",monthlyChange:"http://www.quandl.com/api/v1/multisets.json?columns={{sets}}&collapse=monthly&auth_token={{token}}&rows=1&transformation=rdiff&rows=4",yahooIndex:"https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.quoteslist%20where%20symbol%20in%20({{quotes}})&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=",events:"www.dailyfx.com/files/Calendar-{{startWeekDate}}.csv",yql:"https://query.yahooapis.com/v1/public/yql?q={{query}}&format=json&diagnostics=false&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys"},correlation:{min:.7},yqls:{quotes:"select * from yahoo.finance.quote where symbol in ({{sets}})"},maps:{currency:[{country:"us",code:"USD",cot:"U.S. DOLLAR INDEX"},{country:"nz",code:"NZD",cot:"NEW ZEALAND DOLLAR"},{country:"au",code:"AUD",cot:"AUSTRALIAN DOLLAR"},{country:"ca",code:"CAD",cot:"CANADIAN DOLLAR"},{country:"ch",code:"CHF",cot:"SWISS FRANC"},{country:"jp",code:"JPY",cot:"JAPANESE YEN"},{country:"gb",code:"GBP",cot:"BRITISH POUND STERLING"},{country:"em",code:"EUR",cot:"EURO FX"}],tickers:[{quandl:"YAHOO.INDEX_GDAXI",symbol:"GDAXI",name:"DAX"},{quandl:"YAHOO.INDEX_FTSE",symbol:"FTSE",name:"FTSE"},{quandl:"YAHOO.INDEX_AORD",symbol:"AORD",name:"AORD"},{quandl:"NIKKEI.INDEX",symbol:"N225",name:"NIKKEI"},{quandl:"YAHOO.INDEX_GSPTSE",symbol:"GSPTSE",name:"GSPTSE"},{quandl:"OFDP.SILVER_5",symbol:"SIN14.CMX",name:"SILVER"},{quandl:"WGC.GOLD_DAILY_USD",symbol:"GCN14.CMX",name:"GOLD"},{quandl:"WSJ.COPPER",symbol:"HGN14.CMX",name:"COPPER"},{quandl:"WSJ.CORN_2",symbol:"CU14.CBT",name:"CORN"},{quandl:"WSJ.PL_MKT",symbol:"PLN14.NYM",name:"PLATINUM"},{quandl:"OFDP.FUTURE_B1",symbol:"CLQ14.NYM",name:"OIL"},{quandl:"FED.JRXWTFB_N_B",symbol:"DX-Y.NYB",name:"DOLLAR INDEX"}]}},a.$watch("selected.cross",function(b){if(angular.isDefined(b)&&null!==b){var c=b.displayName.split("/");a.selected.cross1=c[0],a.selected.cross2=c[1],g.url("/app/cross/"+a.selected.cross1+a.selected.cross2)}else a.selected.cross1=a.selected.cross2=null}),a.toggleLeft=function(){b.$getByHandle("menuLeft").toggleLeft()},a.init=function(){for(var b in a.config.urls)a.config.urls[b]=a.config.urls[b].replace(/\{\{token\}\}/gi,a.config.token);csv2json.csv("data/availableCrosses.csv",function(b){a.data.currencies=b})},a.getRandom=function(){return Math.ceil(Math.random()+Date.now())}}]),angular.module("aifxApp").controller("analyticsController",["$scope","$ionicSideMenuDelegate","$http","$stateParams","$timeout","$q","ngTableParams","$ionicPopup","$location",function(a,b,c,d,e,f,g,h,i){a.tblEvents=new g({},{counts:[]}),a.nextEvents=null,a.nxtEvent=null,a.optsHighchartsCross={scrollbar:{enabled:!1},exporting:{enabled:!1},options:{navigator:{enabled:!0,adaptToUpdatedData:!1}},title:{text:!1},series:[{name:"Average Markets Price",data:null,type:"candlestick",pointInterval:null,cursor:"pointer",point:{events:{click:function(){a.showCandlestickPatterns({x:this.options.x,patterns:a.selected.patterns[this.options.x]})}}},id:"prices"},{name:"Regression",data:null,type:"spline",pointInterval:null},{type:"flags",data:null,shape:"circlepin"},{type:"flags",data:null,onSeries:"prices",shape:"url(images/icon-question.png)",cursor:"pointer",point:{events:{click:function(){var b=this;a.showCandlestickPatterns(b)}}}}],useHighStocks:!0,credits:{enabled:!1},xAxis:{type:"datetime"}},a.optsHighchartsVolatility={scrollbar:{enabled:!1},exporting:{enabled:!1},chart:{type:"column",zoomType:"x"},plotOptions:{series:{stacking:""}},xAxis:{categories:[]},yAxis:{title:{text:"Volatility"}},series:[{data:[],name:"Major Crosses",cursor:"pointer",type:"column",point:{events:{click:function(){var a=this;e(function(){i.url("/app/cross/"+a.name.replace(/[^a-z]+/gi,""))},50)}}}}],title:{text:!1}},a.optsHighchartsStrength={scrollbar:{enabled:!1},exporting:{enabled:!1},chart:{type:"column",zoomType:"x"},xAxis:{categories:[]},yAxis:{title:{text:"Strength"}},series:[{data:[],name:"Major Economies"}],title:{text:!1}},a.optsHighchartsCurrencyForce={scrollbar:{enabled:!1},exporting:{enabled:!1},chart:{type:"column",zoomType:"x"},plotOptions:{series:{stacking:""}},xAxis:{categories:[]},yAxis:{title:{text:"Currency Force"}},series:[{data:[],name:"Major Currencies"}],title:{text:!1}},Highcharts.setOptions({global:{useUTC:!1}}),Highcharts.setTheme("steel"),a.optsChartPeriods=[{label:"Intraday",granularity:"M15",pointInterval:9e5},{label:"Week",granularity:"H1",pointInterval:36e5},{label:"Month",granularity:"H4",pointInterval:144e5},{label:"Year",granularity:"D",pointInterval:864e5}],a.optChartPeriod=null,a.stats="force",a.start=function(b,c){angular.isDefined(d.cross)&&(a.selected.cross1=d.cross.split("").splice(0,3).join(""),a.selected.cross2=d.cross.split("").splice(3,3).join(""),a.selected.cross=jsonPath.eval(a.data.currencies,'$[?(@.displayName=="'+[a.selected.cross1,a.selected.cross2].join("/")+'")]')[0]||null);a.selected.cross1+a.selected.cross2,moment().subtract("years",4).format("YYYY-MM-DD"),moment().format("YYYY-MM-DD");(!angular.isDefined(b)||b)&&(a.correlated("markets"),a.processEvents().then(function(){}),a.selected.currency1=jsonPath.eval(a.config.maps.currency,'$[?(@.code == "'+a.selected.cross1+'")]')[0].cot||null,a.selected.currency2=jsonPath.eval(a.config.maps.currency,'$[?(@.code == "'+a.selected.cross2+'")]')[0].cot||null,a.stats="markets"),c&&(a.optChartPeriod=a.optsChartPeriods[0],a.chart(a.optChartPeriod))},a.computeVolatility=function(){a.optsHighchartsVolatility.series[0].data=[];var b=[];csv2json.csv(a.config.urls.api+"candles/volatility",function(c){a.selected.volatility=c,angular.forEach(a.selected.volatility,function(c){b.push({name:c.cross.replace(/_/g,"/"),color:a.utils.getRandomColorCode(),y:parseFloat(c.value)})}),a.$apply(function(){a.optsHighchartsVolatility.series[0].data=b})})},a.computeCurrencyForce=function(){a.optsHighchartsCurrencyForce.series[0].data=[];var b=[],c={};csv2json.csv(a.config.urls.api+"currencyForce",function(d){a.selected.currencyForce=d,Object.keys(d[0]).map(function(a){"period"!==a&&(c[a]=[])}),angular.forEach(a.selected.currencyForce,function(a){var b=a.period||null;null!==b&&Object.keys(c).map(function(b){c[b].push(parseFloat(a[b]))})}),Object.keys(c).map(function(d){var e=math.mean(c[d]),f=jsonPath.eval(a.config.maps.currency,'$[?(@.code == "'+d+'")]')[0];b.push({name:d,color:a.utils.getRandomColorCode(),y:e,marker:{symbol:"url(images/flags/"+[angular.lowercase(/em/i.test(f.country)?"europeanunion":f.country),"png"].join(".")+")"}})}),b.sort(function(a,b){return a.y>b.y?-1:a.y<b.y?1:0}),a.$apply(function(){a.optsHighchartsCurrencyForce.series[0].data=b})})},a.computeStrength=function(){a.optsHighchartsStrength.series[0].data=[];var b=[];csv2json.csv(a.config.urls.api+["calendar","strength",52].join("/"),function(c){a.selected.strength=c,angular.forEach(a.selected.strength,function(c){b.push({name:c.country,color:a.utils.getRandomColorCode(),y:parseFloat(c.strength),marker:{symbol:"url(images/flags/"+[angular.lowercase(/em/i.test(c.country)?"europeanunion":c.country),"png"].join(".")+")"}})}),a.$apply(function(){a.optsHighchartsStrength.series[0].data=b})})},a.computeChange=function(b,d){var e=f.defer();switch(d){case"weeklyChange":case"monthlyChange":c.get(a.config.urls[d].replace(/\{\{sets\}\}/gi,b.join(","))).success(function(b){var c={};if(angular.isArray(b.column_names)&&angular.isArray(b.data)){angular.forEach(b.column_names,function(a,b){0!==b&&(c[a.replace(/^(?:CURRFX\.)?([^\s]+).*$/gi,"$1")]=null)});var f=Object.keys(c);angular.forEach(b.data,function(b){angular.forEach(b,function(b,e){if(0!==e&&null!==b&&null===c[f[e-1]]){var g=f[e-1],h=jsonPath.eval(a.config.maps.tickers,'$.[?(@.quandl=="'+g+'")]')[0]||!1;h?(c[g]=b,jsonPath.eval(a.selected.correlation.markets,'$[?(@.cross && @.cross == "'+g+'")]')[0][d]=b):jsonPath.eval(a.selected.correlation.markets,'$[?(@.cross && @.cross == "'+g+'")]')[0].currency=!0,jsonPath.eval(a.selected.correlation.markets,'$[?(@.cross && @.cross == "'+g+'")]')[0].label=g}})})}e.resolve()}).error(function(a){e.reject(a)});break;case"dailyChange":var g=a.config.maps.tickers.map(function(a){var b='"'+(/\./g.test(a.symbol)?a.symbol:"^"+a.symbol)+'"';return b}),h=a.config.yqls.quotes.replace(/\{\{sets\}\}/gi,g.join(","));c.get(a.config.urls.yql.replace(/\{\{query\}\}/gi,encodeURIComponent(h))).success(function(b){angular.isDefined(b.query)&&angular.isObject(b.query.results)&&angular.isArray(b.query.results.quote)&&angular.forEach(b.query.results.quote,function(b){var c=b.Symbol.replace(/\^/g,""),e=jsonPath.eval(a.config.maps.tickers,'$.[?(@.symbol=="'+c+'")]')[0]||null;try{null!==e&&(jsonPath.eval(a.selected.correlation.markets,'$[?(@.cross && @.cross == "'+e.quandl+'")]')[0][d]=b.Change&&parseFloat(b.Change)||0,jsonPath.eval(a.selected.correlation.markets,'$[?(@.cross && @.cross == "'+e.quandl+'")]')[0].label=e.name)}catch(f){}}),e.resolve()}).error(function(a){e.reject(a)})}return e.promise},a.isCurrencyEvent=function(b){var c=new RegExp("("+[a.selected.cross1,a.selected.cross2].join("|")+")","gi");return c.test(b.currency)},a.processEvents=function(){var b=f.defer();a.selected.events=[];var d=1,e=(new RegExp("("+[a.selected.cross1,a.selected.cross2].join("|")+")","gi"),function(a){var b=[];return csv2json.csv.parse(a,function(a){a.Currency=angular.uppercase(a.Currency),b.push(a)}),b}),g=null;switch(moment().day()){case 6:g=moment().add("week",d).startOf("week").format("MM-DD-YYYY");break;case 0:case 1:g=moment().add("week",0).startOf("week").format("MM-DD-YYYY");break;default:g=moment().startOf("week").format("MM-DD-YYYY")}var h=Array.apply(null,new Array(d)).map(String.valueOf,"").map(function(){var b=a.config.urls.events.replace(/\{\{startWeekDate\}\}/gi,g);return"http://"+b});return c.post(a.config.urls.api+"calendar/"+[a.selected.cross1,a.selected.cross2].join(""),h,{cache:!0,headers:{"Content-Type":"application/json"}}).success(function(c){a.selected.events=e(c),a.selected.events=a.selected.events.map(function(b){var c={},d=new RegExp("^("+[a.selected.cross1,a.selected.cross2].join("|")+")\\s+","g");for(var e in b)c[angular.lowercase(e)]=b[e],/event/gi.test(e)&&(c.event=c.event.replace(d,""));return c.localDate=a.utils.parseDate([b.Date,moment().format("YYYY"),b.Time,b["Time Zone"]].join(" ")),c.timestamp=moment(c.localDate).valueOf(),c}).filter(function(a){return""!==a.actual||""!==a.forecast||""!==a.previous}),a.selected.events.sort(function(a,b){return new Date(a.localDate)<new Date(b.localDate)?-1:new Date(a.localDate)>new Date(b.localDate)?1:0}),a.nextEvents=jsonPath.eval(a.selected.events,'$[?(@.actual=="" && (@.currency=="'+a.selected.cross1+'" || @.currency=="'+a.selected.cross2+'"))]')||null,null!==a.nextEvents&&(a.nextEvents=a.nextEvents.filter(function(a){return a.timestamp>=moment().valueOf()})),b.resolve()}).error(b.reject),b.promise},a.correlated=function(b){var c=a.selected.cross1+a.selected.cross2,d=a.selected.cross2+a.selected.cross1,e=null;switch(b){case"markets":e="data/multisetsOutputs.csv";break;case"events":e="data/eventsCrossesOutputs.csv"}csv2json.csv(e,function(e){var f='$[?(@.cross1=="'+c+'" || @.cross2=="'+c+'" || @.cross1=="'+d+'" || @.cross2=="'+d+'")]',g=jsonPath.eval(e,f).map(function(a){var b=parseFloat(a.rel);return a.rel=b,a});a.$apply(function(){var e=[];if(a.selected.correlation[b]=g.map(function(e){"markets"!==b||e.cross1!==d&&e.cross2!==d?"events"!==b||e.cross1!==c&&e.cross2!==c||(e.rel=-e.rel):e.rel=-e.rel,e.cross=e.cross1===c&&e.cross2||e.cross1===d&&e.cross2||e.cross2===c&&e.cross1||e.cross2===d&&e.cross1,delete e.cross1,delete e.cross2;var f=e.cross.split("").splice(0,3).join(""),g=e.cross.split("").splice(3,3).join(""),h=a.api.getOandaCross(f,g)&&a.api.getOandaCross(f,g).instrument||null;return null!==h&&h.replace(/[^a-z]+/gi,"")!==e.cross&&(e.cross=h.replace(/[^a-z]+/gi,""),e.rel=-e.rel),e}).filter(function(c){var d=c.rel>=a.config.correlation.min||c.rel<=-a.config.correlation.min;return d=d&&-1===e.indexOf(c.cross),e.push(c.cross),"events"!==b?d:d&&c.rel>-1&&c.rel<1}),a.selected.correlation[b].sort(function(a,b){return a.rel<b.rel?1:a.rel>b.rel?-1:0}),"markets"===b){var f=[];if(angular.forEach(a.selected.correlation[b],function(c,d){/^[a-z]+\..*$/gi.test(c.cross)?f.push(c.cross+".1"):(a.selected.correlation[b][d].currency=!0,a.selected.correlation[b][d].label=c.cross)}),0===f.length)return;a.computeChange(f,"monthlyChange").then(function(){a.computeChange(f,"weeklyChange").then(function(){a.computeChange(null,"dailyChange")})})}})})},a.chart=function(b){var c=null;switch(a.selected.granularity=b.granularity||null,b.label){case"Intraday":switch(moment().day()){case 6:c=moment().hours(0).subtract("day",1).utc().format(a.utils.rfc3339);break;case 0:c=moment().hours(0).subtract("day",2).utc().format(a.utils.rfc3339);break;default:c=moment().subtract("day",1).utc().format(a.utils.rfc3339)}break;case"Week":c=moment().subtract("week",1).utc().format(a.utils.rfc3339);break;case"Month":c=moment().subtract("month",1).utc().format(a.utils.rfc3339);break;case"Year":c=moment().subtract("year",1).utc().format(a.utils.rfc3339)}var d={instrument:[a.selected.cross1,a.selected.cross2].join("_"),granularity:b.granularity,candleFormat:"bidask",start:c,end:moment().utc().format(a.utils.rfc3339)};a.candlesticksAnalysis(d,b)},a.resetChart=function(){a.optsHighchartsCross.series[0].data=[],a.optsHighchartsCross.series[1].data=[],a.optsHighchartsCross.series[2].data=[],a.optsHighchartsCross.series[3].data=[]},a.candlesticksAnalysis=function(b,c){a.resetChart();var d=a.api.isRevertedCross(a.selected.cross1,a.selected.cross2);csv2json.csv("data/candlePatterns.csv",function(e){a.data.patterns=e.map(function(a){return a.Direction=parseInt(a.Direction),a}),csv2json.csv(a.config.urls.api+["candles",[a.selected.cross1,a.selected.cross2].join(""),b.start.replace(/^([^T]+).*$/gi,"$1"),b.granularity].join("/"),function(b){if(a.$apply(function(){a.resetChart()}),angular.isArray(b)){var e=null,f=[],g=[],h=[];angular.forEach(b,function(b){var c=moment.unix(parseInt(b.Time)).valueOf(),i=parseFloat(d?parseFloat(1/b.Open).toFixed(6):parseFloat(b.Open).toFixed(6)),j=parseFloat(d?parseFloat(1/b.Close).toFixed(6):parseFloat(b.Close).toFixed(6)),k=parseFloat(d?parseFloat(1/b.Low).toFixed(6):parseFloat(b.High).toFixed(6)),l=parseFloat(d?parseFloat(1/b.High).toFixed(6):parseFloat(b.Low).toFixed(6)),m=new Array(c,i,k,l,j),n=!0,o="1"===b.UpTrend;"NA"===b.Trend||"1"===b.NoTrend?n=!1:null!==e&&(o&&"UP"===e.title||!o&&"DOWN"===e.title)&&(n=!1),n&&(e={title:o?"UP":"DOWN",text:o?"UP":"DOWN",x:c.valueOf()},g.push(e));var p=[],q=!1;for(var r in b){b[r]=parseInt(b[r]);var s=new RegExp("Open|High|Low|Close|Volume|UpTrend|NoTrend|DownTrend|Trend|Time","i");if(!s.test(r)&&(q||1!==b[r]||(q=!0),1===b[r])){var t=r.replace(/\.\d+/g,"").replace(/([A-Z])|\./g," $1").trim().replace(/\s{1,}/g," ").replace(/(\b)day(\b)/gi,"$1Bar$2"),u=jsonPath.eval(a.data.patterns,'$.[?(@.Name == "'+t+'")]')[0]||null;null!==u?p.push(u):console.log(t)}}q&&(h.push({title:" ",x:c.valueOf(),text:"Patterns detected",patterns:p}),a.selected.patterns[c.valueOf()]=p),f.push(m)}),a.$apply(function(){a.optsHighchartsCross.series[0].data=f,a.optsHighchartsCross.series[0].pointInterval=c.pointInterval;var b=regression("exponential",a.optsHighchartsCross.series[0].data);a.optsHighchartsCross.series[1].pointInterval=c.pointInterval,a.optsHighchartsCross.series[1].data=b.points,a.optsHighchartsCross.series[2].data=g,a.optsHighchartsCross.series[3].data=h})}})})},a.showCandlestickPatterns=function(b){a.selected.flag=b;var c=a.$new(),d=h.alert({title:"Candlestick Patterns",templateUrl:"views/patterns.html",scope:c});d.then(function(){})}}]),angular.module("aifxApp").controller("portfolioController",["$scope","$ionicSideMenuDelegate","$http","$stateParams","$timeout","$q","$location",function(a,b,c,d,e,f,g){a.optsHighchartsPortfolio={options:{scrollbar:{enabled:!1},exporting:{enabled:!1},chart:{type:"column",zoomType:"x"},plotOptions:{series:{stacking:""}}},xAxis:{categories:[]},yAxis:{title:{text:"Allocation"}},series:[{data:[],name:"Major Crosses",cursor:"pointer",point:{events:{click:function(){var a=this;e(function(){g.url("/app/cross/"+a.name)},50)}}}}],title:{text:!1}},Highcharts.setOptions({global:{useUTC:!1}}),a.optChartPeriod=null,a.start=function(){a.optsHighchartsPortfolio.series[0].data=[];var b=[];csv2json.csv(a.config.urls.api+"portfolio",function(c){a.selected.portfolio=c,angular.forEach(a.selected.portfolio,function(c){b.push({name:c.cross,color:a.utils.getRandomColorCode(),y:parseFloat(c.percentage)})}),a.$apply(function(){a.optsHighchartsPortfolio.series[0].data=b})})}}]);var oandaCurrencies=null;csv2json.csv("data/oandaCurrencies.csv",function(a){oandaCurrencies=a}),angular.module("aifxApp").service("api",["$http","$q",function(a,b){var c=!1,d="ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786",e=c?"http://api-sandbox.oanda.com":"https://api-fxpractice.oanda.com",f=e+"/v1/candles?{{params}}&weeklyAlignment=Monday";return{isRevertedCross:function(a,b){return 0===jsonPath.eval(oandaCurrencies,'$.[?(@.instrument=="'+[a,b].join("_")+'")]').length},getOandaCross:function(a,b){var c=[a,"_",b].join(""),d=[b,"_",a].join(""),e=jsonPath.eval(oandaCurrencies,'$.[?(@.instrument=="'+c+'" || @.instrument=="'+d+'")]')[0]||null;return e},getCandlesticks:function(c){var e=this,g=b.defer(),h=c.instrument.split("_")[0],i=c.instrument.split("_")[1],j=e.getOandaCross(h,i);h=null===j?c.instrument.split("_")[1]:h,i=null===j?c.instrument.split("_")[0]:i,c.instrument=null===j?h+"_"+i:j.instrument,c.candleFormat=angular.isDefined(c.candleFormat)?c.candleFormat:"midpoint";var k=[];for(var l in c)null!==c[l]&&k.push(l+"="+encodeURIComponent(c[l]));var m=f.replace(/\{\{params\}\}/gi,k.join("&"));return a.get(m,{headers:{Authorization:"Bearer "+d,Accept:"application/json"},cache:!0}).success(function(a){g.resolve({data:a,isRevertedCross:e.isRevertedCross(h,i)})}).error(g.reject),g.promise}}}]),angular.module("aifxApp").service("utils",function(){return{rfc3339:"YYYY-MM-DDTHH:mm:ssZ",parseDate:function(a){return moment(a).zone(moment().zone()).toDate()},formatDate:function(a,b){return b=b||this.rfc3339,moment(a).zone(moment().zone()).format(b)},getRandomColorCode:function(){for(var a="0123456789ABCDEF".split(""),b="#",c=0;6>c;c++)b+=a[Math.floor(16*Math.random())];return b}}});var qfxServices=qfxServices||angular.module("aifxApp.services",[]);qfxServices.provider("log",function(){var a=null;this.$get=["$timeout",function(b){return{level:{notice:1,success:2,warning:3,error:4},current:null,clear:function(){this.current=null},display:function(a,c,d){var e=this;e.current={msg:a,level:c},angular.isNumber(d)&&b(function(){e.current=null},d)},spinner:function(b){if(b||null!==a)null!==a&&b&&(a.stop(),a=null);else{var c={lines:11,length:15,width:6,radius:17,corners:1,rotate:22,direction:1,color:"#000",speed:.7,trail:76,shadow:!0,hwaccel:!0,className:"spinner",zIndex:2e9,top:"50%",left:"50%"},d=document.querySelectorAll("body")[0];a=new Spinner(c).spin(d)}}}}]}),angular.module("aifxApp").directive("rateChange",["$interval","$http","api",function(a,b,c){return{template:"<span></span>",restrict:"E",scope:{symbol:"=",period:"@",count:"="},link:function(a){var b=angular.isObject(a.symbol)?a.symbol.label:a.symbol,d=b.split("").splice(0,3).join(""),e=b.split("").splice(3,3).join("");c.getCandlesticks({instrument:d+"_"+e,granularity:a.period,count:a.count}).then(function(b){var f=c.isRevertedCross(d,e);b.data.candles.sort(function(a,b){var c=new Date(a.time),d=new Date(b.time);return c>d?-1:d>c?1:0});var g=b.data.candles[0].closeMid-b.data.candles[1].closeMid;switch(a.period){case"D":a.symbol.dailyChange=f?-g:g;break;case"W":a.symbol.weeklyChange=f?-g:g;break;case"M":a.symbol.monthlyChange=f?-g:g}})}}}]);