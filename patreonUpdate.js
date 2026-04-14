const https = require("https");
let _ = require("lodash");
let creator_access_token = process.env.NODE_PATREON_TOKEN;
let campaignID = "440241";
const fs = require("fs");

let apiPath = `campaigns/${campaignID}/members`;

function getData(path, params, done) {
  let urlStr = `https://www.patreon.com/api/oauth2/v2/${path}`;

  if (params) {
    urlStr = `${urlStr}?${params}`;
  }
  console.log("URL", urlStr);
  const url = new URL(urlStr);
  const options = {
    hostname: url.hostname,
    path: url.pathname + url.search,
    headers: {
      Authorization: "Bearer " + creator_access_token,
      "User-Agent": "PostmanRuntime/7.39.0",
    },
  };
  https.get(options, (res) => {
    let raw = "";
    res.on("data", (chunk) => { raw += chunk; });
    res.on("end", () => {
      let body;
      try {
        body = JSON.parse(raw);
      } catch (error) {
        return console.log(error, raw);
      }
      return done(null, body);
    });
  }).on("error", (err) => {
    console.log("error trying to update patreon info ", err);
    return done(err);
  });
}

function getMembers(members, newpath, done) {
  return getData(apiPath, newpath, function (err, body) {
    if (err || !body || !body.data) {
      console.error("Patreon API returned unexpected response:", JSON.stringify(body || {}).substring(0, 500));
      return done(err || new Error("No data in Patreon response"), members);
    }

    // Build tier map from included resources
    const tierMap = {};
    if (body.included) {
      body.included.forEach(function (inc) {
        if (inc.type === "tier") {
          tierMap[inc.id] = inc.attributes.title;
        }
      });
    }

    // Process each member — only active patrons on the Special Access tier
    body.data.forEach(function (member) {
      const attrs = member.attributes;
      if (attrs.patron_status !== "active_patron") return;

      const tierIds =
        (member.relationships &&
          member.relationships.currently_entitled_tiers &&
          member.relationships.currently_entitled_tiers.data) ||
        [];
      const tiers = tierIds.map(function (t) {
        return tierMap[t.id] || "";
      });
      const hasSpecialAccess = tiers.some(function (t) {
        return t.toLowerCase().includes("special access");
      });

      if (hasSpecialAccess) {
        members.push(attrs.full_name);
      }
    });

    if (body.links && body.links.next) {
      let params = new URL(body.links.next).searchParams;
      // Small delay to avoid Patreon rate limiting
      return setTimeout(function () {
        getMembers(members, params.toString(), done);
      }, 200);
    }

    return done(null, members);
  });
}

getMembers(
  [],
  "include=currently_entitled_tiers&fields%5Bmember%5D=full_name%2Cpatron_status&fields%5Btier%5D=title",
  function (err, result) {
    let memberList = _.sortBy(result);
    let output = `local GSE = GSE
local Statics = GSE.Static

Statics.Patrons = {
    [[${memberList.join("]],\n    [[")}]]
}`;
    console.log(output);
    fs.writeFile("GSE_Utils/Patrons.lua", output, (err) => {
      if (err) {
        console.error(err);
      }
    });
  }
);
