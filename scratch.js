const { Innertube } = require('youtubei.js');
async function run() {
  const yt = await Innertube.create();
  const info = await yt.getBasicInfo("jNQXAC9IVRw", { client: "ANDROID_VR" });
  const format = info.chooseFormat({ type: 'audio', quality: 'best' });
  console.log("ANDROID_VR format:", format.mime_type, format.bitrate);
  let url = format.url;
  if (!url && (format.signatureCipher || format.cipher)) url = await format.decipher(yt.session.player);
  console.log("has valid url:", !!url);
}
run().catch(console.error);
