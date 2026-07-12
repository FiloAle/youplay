import { Innertube } from 'youtubei.js';
async function run() {
  const yt = await Innertube.create({ retrieve_player: false });
  const search = await yt.search("Nico Schira");
  const video = search.videos[0];
  console.log("video id:", video.id);
  console.log("hq720:", `https://i.ytimg.com/vi/${video.id}/hq720.jpg`);
  console.log("maxresdefault:", `https://i.ytimg.com/vi/${video.id}/maxresdefault.jpg`);
  console.log("thumbnails:", JSON.stringify((video as any).thumbnails, null, 2));
}
run();
