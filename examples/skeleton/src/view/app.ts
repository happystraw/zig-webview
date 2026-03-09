const countEl = document.getElementById("count");
const btnDec = document.getElementById("btn-dec");
const btnInc = document.getElementById("btn-inc");
const btnReset = document.getElementById("btn-reset");

function render(count: number) {
    if (!countEl) return;
    countEl.textContent = String(count);
    countEl.className = count > 0 ? "positive" : count < 0 ? "negative" : "zero";
}

if (btnInc) btnInc.addEventListener("click", async () => { render(await window.count(1)); });
if (btnDec) btnDec.addEventListener("click", async () => { render(await window.count(-1)); });
if (btnReset) btnReset.addEventListener("click", async () => { render(await window.reset()); });
