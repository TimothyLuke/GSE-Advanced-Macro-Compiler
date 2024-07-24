let _ = require("lodash");
let async = require("async");
const fs = require("fs");
var BuildVersion = false;
var BuildNumber = "";

function lines(text) {
  return text.split("\n");
}

function updateToc(path, filename, done) {
  fs.readFile(`.release/${path}/${filename}.toc`, "utf8", (err, data) => {
    if (err) {
      console.log(`Unable to read ${path}/${filename}`);
      console.error(err);
      return done(err);
    }
    var tocLines = lines(data);
    var tocIndex = _.findIndex(tocLines, function (o) {
      return o.startsWith("## Version:");
    });
    var version = `${tocLines[tocIndex]}-PatronBuild`.replace(
      /(\r\n|\n|\r)/gm,
      ""
    );
    tocLines[tocIndex] = version;
    if (!BuildVersion) {
      BuildVersion = version;
      console.log(`BuildVersion set to ${BuildVersion}`);
      var n = BuildVersion.split(" ");
      console.log(n);
      BuildNumber = n[n.length - 1];
    }

    fs.writeFile(
      `.release/${path}/${filename}.toc`,
      `${tocLines.join("\n")}`,
      (err) => {
        if (err) {
          return done(err);
        }
        console.log(`Updated ${path}/${filename}`);
        return done();
      }
    );
  });
}

function addExtras(done) {
  const srcDir = `./GSE_QoL`;
  const destDir = `./.release/GSE_QoL`;

  fs.cpSync(srcDir, destDir, { recursive: true });
  return done();
}

function createArchive(done) {
  const archiver = require("archiver");
  const output = fs.createWriteStream(`GSE-${BuildNumber}.zip`);
  const archive = archiver("zip", {
    zlib: { level: 9 }, // Sets the compression level.
  });

  output.on("close", function () {
    console.log(archive.pointer() + " total bytes");
    console.log(
      "archiver has been finalized and the output file descriptor has closed."
    );
    return done();
  });

  output.on("end", function () {
    console.log("Data has been drained");
  });
  archive.pipe(output);
  archive.directory(".release", false);

  archive.finalize();
}

function publishArchive(done) {
  const { Webhook, MessageBuilder } = require("discord-webhook-node");
  const hook = new Webhook(process.env.DISCORD_WEBHOOK);

  const embed = new MessageBuilder()
    // .setTitle(`GSE ${BuildVersion}`)
    .setAuthor(
      "GSE Updater",
      "https://media.forgecdn.net/attachments/372/575/gse2-logo-dark-2x.png",
      "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler.com"
    )
    //   .setURL(
    //     "https://www.https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler.com"
    //   )
    .addField("New GSE Update", `${BuildNumber} Released`, true)
    //   .addField("Second field", "this is not inline")
    .setColor("#00b0f4")
    .setThumbnail(
      "https://media.forgecdn.net/attachments/372/575/gse2-logo-dark-2x.png"
    )
    //   .setDescription("Oh look a description :)")
    //   .setImage("https://cdn.discordapp.com/embed/avatars/0.png")
    //   .setFooter(
    //     "Hey its a footer",
    //     "https://cdn.discordapp.com/embed/avatars/0.png"
    //   )
    .setTimestamp();

  hook.send(embed);
  hook.sendFile(`GSE-${BuildNumber}.zip`);
  return done();
}

function deleteExistingZips(done) {
  fs.readdir(".release", (err, files) => {
    for (const file of files) {
      console.log(`Processing File .release/${file}`);
      if (file.endsWith("zip")) {
        return fs.unlink(`.release/${file}`, done);
      }
      if (file.endsWith("json")) {
        return fs.unlink(`.release/${file}`, done);
      }
    }
  });
}

async.waterfall(
  [
    async.apply(updateToc, "GSE", "GSE"),
    // async.apply(updateToc, "GSE", "GSE_Vanilla"),
    //async.apply(updateToc, "GSE", "GSE_Cata"),
    async.apply(updateToc, "GSE_GUI", "GSE_GUI"),
    //async.apply(updateToc, "GSE_GUI", "GSE_GUI_Vanilla"),
    //async.apply(updateToc, "GSE_GUI", "GSE_GUI_Cata"),
    async.apply(updateToc, "GSE_LDB", "GSE_LDB"),
    //async.apply(updateToc, "GSE_LDB", "GSE_LDB_Vanilla"),
    //async.apply(updateToc, "GSE_LDB", "GSE_LDB_Cata"),
    async.apply(updateToc, "GSE_Utils", "GSE_Utils"),
    //async.apply(updateToc, "GSE_Utils", "GSE_Utils_Vanilla"),
    //async.apply(updateToc, "GSE_Utils", "GSE_Utils_Cata"),
    deleteExistingZips,
    addExtras,
    createArchive,
    publishArchive,
  ],
  function (err) {
    console.log(err);
  }
);
