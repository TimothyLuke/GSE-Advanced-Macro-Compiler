const axios = require("axios");

let creator_access_token = "";
let campaignID = "440241";

axios
  .get({
    url: `https://www.patreon.com/api/oauth2/api/campaigns/${campaignID}/pledges`,
    headers: {
      Authorization: `Bearer ${creator_access_token}`,
    },
    credentials: "include",
  })
  .then(({ members }) => {
    console.log(members);
  })
  .catch(({ err }) => {
    console.log("err", err);
  });
