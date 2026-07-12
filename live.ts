import { Innertube } from 'youtubei.js';
async function run() {
  const yt = await Innertube.create({ retrieve_player: false });
  // search for a live video, e.g. lofi hip hop radio
  const search = await yt.search("lofi hip hop radio live");
  const liveVideo = search.videos.find(v => (v as any).is_live);
  if (liveVideo) {
    const info = await yt.getBasicInfo(liveVideo.id);
    console.log("duration:", info.basic_info.duration);
    console.log("is_live:", info.basic_info.is_live);
  }
}
run();
