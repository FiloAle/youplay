import { Innertube } from 'youtubei.js';
async function run() {
  const yt = await Innertube.create({ retrieve_player: false });
  const channel = await yt.getChannel("UCX6OQ3DkcsbYNE6H8uQQuVA"); // mrbeast or anyone
  const videos = await channel.getVideos();
  const video = videos.videos[0];
  console.log("video.thumbnails", JSON.stringify(video.thumbnails, null, 2));
  console.log("video.content_image?.image", JSON.stringify((video as any).content_image?.image, null, 2));
}
run();
