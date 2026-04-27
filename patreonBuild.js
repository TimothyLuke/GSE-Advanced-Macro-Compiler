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
    
    // version = version.replace("3.2", "3.3.0-midnight-beta-0")

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

// GSE_QoL is excluded from the BigWigs packager via .pkgmeta `ignore:`,
// so its `## Version: @project-version@` token never gets substituted by
// the packager. addExtras above just cpSync's the source folder (token
// and all). Here we copy the resolved Version line from GSE/GSE.toc —
// which BigWigs DID substitute, and which updateToc(GSE) further
// appended `-PatronBuild` to in this waterfall — onto the QoL toc so
// patrons get the same versioned suffix as the rest of the bundle.
function syncQoLVersionFromGSE(done) {
  const gseTocPath = `./.release/GSE/GSE.toc`;
  const qolTocPath = `./.release/GSE_QoL/GSE_QoL.toc`;
  fs.readFile(gseTocPath, "utf8", (err, gseData) => {
    if (err) {
      console.log(`[syncQoLVersion] cannot read ${gseTocPath}`);
      return done(err);
    }
    const versionLine = lines(gseData).find((l) =>
      l.startsWith("## Version:")
    );
    if (!versionLine) {
      return done(new Error(`No "## Version:" line in ${gseTocPath}`));
    }
    fs.readFile(qolTocPath, "utf8", (err2, qolData) => {
      if (err2) {
        console.log(`[syncQoLVersion] cannot read ${qolTocPath}`);
        return done(err2);
      }
      const qolLines = lines(qolData);
      const idx = qolLines.findIndex((o) => o.startsWith("## Version:"));
      if (idx < 0) {
        return done(new Error(`No "## Version:" line in ${qolTocPath}`));
      }
      const cleanedVersion = versionLine.replace(/(\r\n|\n|\r)/gm, "");
      qolLines[idx] = cleanedVersion;
      fs.writeFile(qolTocPath, qolLines.join("\n"), (err3) => {
        if (err3) return done(err3);
        console.log(
          `[syncQoLVersion] GSE_QoL.toc Version set to: ${cleanedVersion}`
        );
        return done();
      });
    });
  });
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
  const {
    EmbedBuilder,
    WebhookClient,
    AttachmentBuilder,
  } = require("discord.js");

  const hook = new WebhookClient({ url: process.env.DISCORD_WEBHOOK });

  const embed = new EmbedBuilder()
    // .setTitle(`GSE ${BuildVersion}`)
    .setAuthor({
      name: "GSE Updater",
      iconURL:
        "https://media.forgecdn.net/attachments/372/575/gse2-logo-dark-2x.png",
      url: "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler.com",
    })
    //   .setURL(
    //     "https://www.https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler.com"
    //   )
    .addFields({
      name: "New GSE Update",
      value: `${BuildNumber} Released`,
      inline: true,
    })
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

  var file = new AttachmentBuilder(`./GSE-${BuildNumber}.zip`);

  try {
    hook.send({
      embeds: [embed],
      files: [file],
    }).then(function() {
      console.log('[pat] Discord webhook sent');
      return done();
    }).catch(function(err) {
      console.log('[pat] Discord webhook failed:', err.message);
      return done();
    });
  } catch (err) {
    console.log(err);
    return done(err);
  }
}

function deleteExistingZips(done) {
  fs.readdir(".release", (err, files) => {
    for (const file of files) {
      console.log(`Processing File .release/${file}`);
      if (file.endsWith("zip")) {
        // Move the original BigWigs zip to root so publish step can upload it too
        fs.renameSync(`.release/${file}`, `./${file}`);
        console.log(`Moved .release/${file} to ./${file}`);
        return done();
      }
      if (file.endsWith("json")) {
        return fs.unlink(`.release/${file}`, done);
      }
    }
    return done();
  });
}

function closeMessage(done) {
  console.log("Patron Build Complete");
  return done();
}

async.waterfall(
  [
    async.apply(updateToc, "GSE", "GSE"),
    async.apply(updateToc, "GSE_GUI", "GSE_GUI"),
    async.apply(updateToc, "GSE_LDB", "GSE_LDB"),
    async.apply(updateToc, "GSE_Utils", "GSE_Utils"),
    async.apply(updateToc, "GSE_Options", "GSE_Options"),
    deleteExistingZips,
    addExtras,
    syncQoLVersionFromGSE,
    createArchive,
    publishArchive,
    closeMessage,
  ],
  function (err) {
    console.log(err);
  }
);
