import { Innertube } from "youtubei.js";
async function test() {
  const yt = await Innertube.create();
  for (const client of ["WEB", "ANDROID", "TV_EMBED", "WEB_EMBED", "IOS"]) {
    try {
      const info = await yt.getBasicInfo("dQw4w9WgXcQ", { client: client as any });
      const formats = info.streaming_data?.formats?.map(f => f.quality_label) || [];
      console.log(`${client}: ${formats.join(", ")}`);
    } catch (e) {}
  }
}
test().catch(console.error);
