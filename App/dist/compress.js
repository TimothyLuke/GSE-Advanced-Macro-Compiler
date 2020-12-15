'use strict';

var _discourseJs = require('discourse-js');

var _discourseJs2 = _interopRequireDefault(_discourseJs);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var parser = require('./luaparse.js');
var luamin = require('luamin');
var _ = require('lodash');

var fs = require('fs');

var GSE = readGSE("D:\\games\\World of Warcraft\\_retail_\\WTF\\Account\\DRAIKON\\SavedVariables\\GSE.lua");

function readGSE(filename) {
    var data = fs.readFileSync(filename).toString();
    //console.log(data)
    var ast = parser.parse(data, { encodingMode: "pseudo-latin1" });
    return ast;
}

var nodeGSEStorage = _.find(GSE.body, function (node) {
    return _.first(node.variables).name == "GSEStorage";
});

var outputfile = luamin.minify(ast)
console.log(outputfile)

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

// var userApiKey = '8477c8bd319c7b3246a9b4d87e3567d398a785c359a9f828daf9331c8c829210';
// var apiUsername = '<user-username-from-discourse>';
// var baseUrl = 'https://wowlazymacros.com';

// var discourse = new _discourseJs2.default();
// discourse.config({ userApiKey: userApiKey, apiUsername: apiUsername, baseUrl: baseUrl });

// discourse.topics.getTopic({
//     id: 15794,
//     print: true
// }).then(function (res) {
//     return console.log(res);
// }).catch(function (err) {
//     return console.log(err);
// });