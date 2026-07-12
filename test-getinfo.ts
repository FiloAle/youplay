import { Innertube } from "youtubei.js";
async function test() {
  const yt = await Innertube.create();
  const info = await yt.getInfo("dQw4w9WgXcQ");
  const hls = info.streaming_data?.hls_manifest_url ? "YES" : "NO";
  const prog = info.streaming_data?.formats?.length || 0;
  console.log(`getInfo: HLS=${hls}, Prog=${prog}`);
}
test().catch(console.error);
