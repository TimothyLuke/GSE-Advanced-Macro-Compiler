let request = require("request");
let _ = require("lodash");
let creator_access_token = env.NODE_PATREON_TOKEN;
let campaignID = "440241";
const fs = require("fs");

let apiPath = `campaigns/${campaignID}/members`;

function getData(path, params, done) {
  let url = `https://www.patreon.com/api/oauth2/v2/${path}`;

  if (params) {
    url = `${url}?${params}`;
  }
  console.log("URL", url);
  request(
    {
      url,
      headers: {
        Authorization: "Bearer " + creator_access_token,
      },
    },
    (err, result, body) => {
      if (err) return console.log("error trying to update patreon info ", err);
      body = JSON.parse(body);
      return done(err, body);
    }
  );
}

function getMembers(members, newpath, done) {
  return getData(apiPath, newpath, function (err, body) {
    members = _.concat(
      members,
      _.map(body.data, function (member) {
        return _.get(member, "attributes.full_name");
      })
    );
    // console.log(members);
    if (body.links && body.links.next) {
      let params = new URL(body.links.next).searchParams;

      return getMembers(members, params.toString(), done);
    }

    return done(err, members);
  });
}

getMembers([], "fields%5Bmember%5D=full_name", function (err, result) {
  let memberList = _.sortBy(result);
  let output = `local GSE = GSE
local Statics = GSE.Static

Statics.Patrons = {
    "${memberList.join('",\n    "')}"
}`;
  console.log(output);
  fs.writeFile("GSE/API/Patrons.lua", output, (err) => {
    if (err) {
      console.error(err);
    }
  });
});
