var Discourse =require('discourse-api')

var parser = require('luaparse')
var luamin = require('luamin')
var _ = require('lodash')

var fs = require('fs')

var GSE = readGSE("D:\\games\\World of Warcraft\\_retail_\\WTF\\Account\\DRAIKON\\SavedVariables\\GSE.lua")

function readGSE(filename) {
    var data = fs.readFileSync(filename).toString()
    //console.log(data)
    var ast = parser.parse(data, {encodingMode: "pseudo-latin1"})
    return ast
}

console.log("GSE", GSE)

var nodeGSEStorage = _.find(GSE.body, function(node){
    return _.first(node.variables).name == "GSEStorage"
})


console.log(nodeGSEStorage)
var outputfile = luamin.minify(GSE)
console.log(outputfile)

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

const userApiKey = '8b7cb69470e9ee177d4deada060f9d7077824718e86031d2798e2267c6e3d30a'
const apiUsername = 'TimothyLuke';
const baseUrl = 'https://wowlazymacros.com'

var discourse = new Discourse(  baseUrl, userApiKey, apiUsername);


discourse.getTopicAndReplies( '15794', function(err, res, httpcode) {
  console.log(res)
  console.log(err)
  console.log(httpcode)
})