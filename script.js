let count = 0;

const countEl = document.getElementById("count");
const btn = document.getElementById("counter-btn");

btn.addEventListener("click", () => {
  count++;
  countEl.textContent = count;
});
