// Enterprise English Trainer — frontend mantiq (vanilla JS).
"use strict";

const $ = (id) => document.getElementById(id);
let current = null; // joriy mashq (item_id, type, ...)

// --- Yordamchi: server bilan ishlash ---
async function api(path, options) {
  const res = await fetch(path, options);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || "Server xatosi");
  }
  return res.json();
}

// --- Keyingi mashqni yuklash ---
async function loadNext() {
  resetExerciseUI();
  try {
    const ex = await api("/next");
    if (ex.done) {
      $("ex-question").textContent = ex.message_uz;
      $("ex-prompt").textContent = "";
      $("answer-form").classList.add("hidden");
      return;
    }
    current = ex;
    $("answer-form").classList.remove("hidden");
    $("ex-category").textContent = categoryLabel(ex.category);
    $("ex-module").textContent = ex.module || "";
    $("ex-mastery").textContent = `Mahorat: ${ex.mastery}%`;
    $("ex-prompt").textContent = ex.prompt_uz;
    $("ex-question").textContent = ex.question;
    $("hint-text").textContent = ex.hint_uz || "";
    $("answer-input").focus();
  } catch (e) {
    $("ex-question").textContent = "⚠️ " + e.message;
  }
}

function categoryLabel(cat) {
  return {
    vocabulary: "Lug'at",
    word_formation: "So'z yasalishi",
    grammar: "Grammatika",
  }[cat] || cat;
}

// --- Javobni yuborish ---
async function submitAnswer(e) {
  e.preventDefault();
  if (!current) return;
  const answer = $("answer-input").value.trim();
  if (!answer) return;

  try {
    const fb = await api("/answer", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ item_id: current.item_id, answer }),
    });
    showFeedback(fb);
    loadProgress();
  } catch (e) {
    alert(e.message);
  }
}

function showFeedback(fb) {
  $("answer-form").classList.add("hidden");
  $("hint-btn").classList.add("hidden");
  $("hint-text").classList.add("hidden");

  const box = $("feedback");
  box.classList.remove("hidden", "correct", "wrong");
  box.classList.add(fb.correct ? "correct" : "wrong");
  $("feedback-msg").textContent = fb.message_uz;
  $("feedback-mnemonic").textContent = fb.mnemonic_uz || "";
  $("ex-mastery").textContent = `Mahorat: ${fb.mastery}%`;
  $("next-btn").focus();
}

function resetExerciseUI() {
  $("feedback").classList.add("hidden");
  $("hint-btn").classList.remove("hidden");
  $("hint-text").classList.add("hidden");
  $("answer-input").value = "";
}

// --- Jarayon / dashboard ---
async function loadProgress() {
  try {
    const p = await api("/progress");
    // Umumiy
    $("overall-percent").textContent = p.overall.percent + "%";
    $("overall-bar").style.width = p.overall.percent + "%";
    $("overall-label").textContent =
      `Umumiy: ${p.overall.mastered}/${p.overall.total} o'rganildi`;

    // Aniqlik
    const accBox = $("accuracy");
    accBox.innerHTML = "";
    const labels = { vocabulary: "Lug'at", grammar: "Grammatika", word_formation: "So'z yasalishi" };
    const cats = Object.keys(p.category_accuracy);
    if (cats.length === 0) {
      accBox.innerHTML = '<p class="prompt">Hali javob berilmagan.</p>';
    }
    for (const cat of cats) {
      const div = document.createElement("div");
      div.className = "acc-item";
      div.innerHTML = `<div class="pct">${p.category_accuracy[cat]}%</div>
        <div class="lbl">${labels[cat] || cat}</div>`;
      accBox.appendChild(div);
    }

    // Zaif nuqtalar
    const weak = $("weak-list");
    weak.innerHTML = "";
    if (p.weakest_items.length === 0) {
      weak.innerHTML = '<li><span class="prompt">Hali zaif nuqta yo\'q.</span></li>';
    }
    for (const w of p.weakest_items) {
      const li = document.createElement("li");
      li.innerHTML = `<span>${w.item_id} (${categoryLabel(w.category)})</span>
        <span class="lapses">${w.mastery}% · ${w.lapses} xato</span>`;
      weak.appendChild(li);
    }

    // Modullar
    const mods = $("modules");
    mods.innerHTML = "";
    for (const m of p.modules) {
      const row = document.createElement("div");
      row.className = "module-row" + (m.is_complete ? " complete" : "");
      row.innerHTML = `
        <div class="module-head">
          <span>${m.module}${m.is_complete ? " ✓" : ""}</span>
          <span>${m.mastered}/${m.total} · ${m.percent}%</span>
        </div>
        <div class="bar"><div class="bar-fill" style="width:${m.percent}%"></div></div>`;
      mods.appendChild(row);
    }
  } catch (e) {
    console.error(e);
  }
}

// --- Hodisalar ---
$("answer-form").addEventListener("submit", submitAnswer);
$("next-btn").addEventListener("click", loadNext);
$("hint-btn").addEventListener("click", () => {
  $("hint-text").classList.toggle("hidden");
});

// --- Boshlash ---
loadNext();
loadProgress();
