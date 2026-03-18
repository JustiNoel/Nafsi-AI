import { useState, useRef, useEffect } from "react";
import { Send } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import CrisisAlert from "../components/CrisisAlert";
export default function Chat() {
  const [messages, setMessages] = useState([{ role: "assistant", content: "Habari! I'm Nafsi 🌿. How are you feeling today?" }]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [crisis, setCrisis] = useState(null);
  const bottomRef = useRef(null);
  const { token } = useAuth();
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);
  const send = async () => {
    if (!input.trim() || loading) return;
    const userMsg = input.trim(); setInput("");
    setMessages(m => [...m, { role: "user", content: userMsg }]);
    setLoading(true);
    try {
      const res = await fetch("http://localhost:8000/api/chat/stream", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ content: userMsg }),
      });
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let assistantText = "";
      setMessages(m => [...m, { role: "assistant", content: "" }]);
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        for (const line of decoder.decode(value).split("\n")) {
          if (!line.startsWith("data:")) continue;
          const raw = line.slice(5).trim();
          if (raw === "[DONE]") break;
          try {
            const evt = JSON.parse(raw);
            if (evt.type === "crisis") setCrisis(evt);
            if (evt.type === "text") {
              assistantText += evt.content;
              setMessages(m => { const c = [...m]; c[c.length-1] = { role: "assistant", content: assistantText }; return c; });
            }
          } catch {}
        }
      }
    } catch { setMessages(m => [...m, { role: "assistant", content: "I'm having trouble connecting. Please try again." }]); }
    finally { setLoading(false); }
  };
  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto">
      <header className="p-4 border-b bg-white font-semibold text-nafsi-teal text-lg">🌿 Nafsi Chat</header>
      {crisis && <CrisisAlert crisis={crisis} onDismiss={() => setCrisis(null)}/>}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl text-sm ${m.role === "user" ? "bg-nafsi-green text-white" : "bg-white border shadow-sm"}`}>{m.content}</div>
          </div>
        ))}
        {loading && <div className="text-gray-400 text-sm">Nafsi is typing...</div>}
        <div ref={bottomRef}/>
      </div>
      <div className="p-4 border-t bg-white flex gap-2">
        <input className="flex-1 border rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-nafsi-green" placeholder="How are you feeling?" value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === "Enter" && send()}/>
        <button onClick={send} disabled={loading} className="bg-nafsi-green text-white p-2 rounded-full hover:bg-nafsi-teal transition disabled:opacity-50"><Send size={18}/></button>
      </div>
    </div>
  );
}
