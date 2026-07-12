import { Innertube } from 'youtubei.js';
async function run() {
  const yt = await Innertube.create({ retrieve_player: false });
  const info = await yt.getBasicInfo("8J9DPFpXaOs");
  console.log(JSON.stringify(info.basic_info.thumbnail, null, 2));
}
run();
