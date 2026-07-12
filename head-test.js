async function run() {
  const res1 = await fetch("https://i.ytimg.com/vi/iYlODtkyw_I/hq720.jpg", { method: "HEAD" });
  console.log("hq720 mrbeast:", res1.status);
  const res2 = await fetch("https://i.ytimg.com/vi/8J9DPFpXaOs/hq720.jpg", { method: "HEAD" });
  console.log("hq720 nico schira:", res2.status);
  const res3 = await fetch("https://i.ytimg.com/vi/8J9DPFpXaOs/hqdefault.jpg", { method: "HEAD" });
  console.log("hqdefault nico schira:", res3.status);
}
run();
