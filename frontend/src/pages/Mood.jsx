import { useState, useEffect } from "react";
import api from "../services/api";
const EMOTIONS = ["😊 Happy","😢 Sad","😤 Angry","😰 Anxious","😴 Tired","💪 Strong","😕 Confused","🤗 Grateful"];
export default function Mood() {
  const [score, setScore] = useState(5);
  const [tags, setTags] = useState([]);
  const [note, setNote] = useState("");
  const [history, setHistory] = useState([]);
  const [saved, setSaved] = useState(false);
  useEffect(() => { api.get("/mood/history").then(r => setHistory(r.data)).catch(() => {}); }, []);
  const toggle = tag => setTags(t => t.includes(tag) ? t.filter(x => x !== tag) : [...t, tag]);
  const submit = async () => {
    await api.post("/mood/", { score, emotion_tags: tags, journal_note: note });
    setSaved(true); setTimeout(() => setSaved(false), 2000);
    setNote(""); setTags([]);
    api.get("/mood/history").then(r => setHistory(r.data)).catch(() => {});
  };
  return (
    <div className="max-w-xl mx-auto p-6 space-y-6">
      <h1 className="text-2xl font-bold text-nafsi-teal">🌡️ Mood Check-in</h1>
      <div>
        <p className="text-sm text-gray-500 mb-2">How would you rate your mood? ({score}/10)</p>
        <input type="range" min={1} max={10} value={score} onChange={e => setScore(+e.target.value)} className="w-full accent-nafsi-green"/>
      </div>
      <div>
        <p className="text-sm text-gray-500 mb-2">What are you feeling?</p>
        <div className="flex flex-wrap gap-2">
          {EMOTIONS.map(e => (
            <button key={e} onClick={() => toggle(e)} className={`px-3 py-1 rounded-full text-sm border transition ${tags.includes(e) ? "bg-nafsi-green text-white border-nafsi-green" : "border-gray-300 hover:border-nafsi-green"}`}>{e}</button>
          ))}
        </div>
      </div>
      <textarea className="w-full border rounded-xl p-3 text-sm focus:outline-none focus:ring-2 focus:ring-nafsi-green" rows={3} placeholder="Any thoughts you'd like to journal..." value={note} onChange={e => setNote(e.target.value)}/>
      <button onClick={submit} className="w-full bg-nafsi-green text-white py-2 rounded-xl font-medium hover:bg-nafsi-teal transition">{saved ? "✓ Saved!" : "Log Mood"}</button>
      {history.length > 0 && (
        <div>
          <h2 className="font-semibold text-gray-700 mb-2">Recent entries</h2>
          <div className="space-y-2">
            {history.slice(0,5).map(m => (
              <div key={m.id} className="bg-white border rounded-xl p-3">
                <span className="font-bold text-nafsi-green">{m.score}/10</span>
                <span className="text-xs text-gray-400 ml-2">{new Date(m.created_at).toLocaleDateString()}</span>
                {m.journal_note && <p className="text-sm text-gray-500 mt-1">{m.journal_note}</p>}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
