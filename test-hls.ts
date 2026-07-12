import { Innertube } from "youtubei.js";
async function test() {
  const yt = await Innertube.create();
  const info = await yt.getBasicInfo("dQw4w9WgXcQ", { client: "IOS" });
  console.log("HLS Manifest:", info.streaming_data?.hls_manifest_url);
  console.log("Formats:", info.streaming_data?.formats?.map(f => f.quality_label));
}
test().catch(console.error);
