import { Innertube } from "youtubei.js";
async function test() {
  const yt = await Innertube.create();
  for (const client of ["WEB", "ANDROID", "ANDROID_VR", "TV_EMBED", "WEB_EMBED", "IOS"]) {
    try {
      const info = await yt.getBasicInfo("dQw4w9WgXcQ", { client: client as any });
      const hls = info.streaming_data?.hls_manifest_url ? "YES" : "NO";
      const prog = info.streaming_data?.formats?.length || 0;
      console.log(`${client}: HLS=${hls}, Prog=${prog}`);
    } catch (e) {}
  }
}
test().catch(console.error);
