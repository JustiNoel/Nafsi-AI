import { useAuth } from "../context/AuthContext";
import { Link } from "react-router-dom";
export default function Dashboard() {
  const { user, logout } = useAuth();
  return (
    <div className="min-h-screen bg-nafsi-light">
      <nav className="bg-white shadow-sm px-6 py-4 flex justify-between items-center">
        <span className="text-nafsi-teal font-bold text-lg">🌿 Nafsi AI</span>
        <div className="flex items-center gap-4">
          <span className="text-sm text-gray-500">Hi, {user?.full_name}</span>
          <button onClick={logout} className="text-sm text-red-400 hover:text-red-600">Logout</button>
        </div>
      </nav>
      <div className="max-w-3xl mx-auto p-8 grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
        {[
          { to: "/chat", label: "💬 Talk to Nafsi", desc: "Start a conversation with your AI companion" },
          { to: "/mood", label: "🌡️ Log Your Mood", desc: "Track your emotional wellbeing" },
          { to: "/resources", label: "📋 Find Resources", desc: "Therapists, hotlines across Africa" },
        ].map(card => (
          <Link key={card.to} to={card.to} className="bg-white rounded-2xl p-6 shadow-sm hover:shadow-md transition border border-transparent hover:border-nafsi-accent">
            <h2 className="text-lg font-bold text-nafsi-teal">{card.label}</h2>
            <p className="text-sm text-gray-500 mt-1">{card.desc}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
