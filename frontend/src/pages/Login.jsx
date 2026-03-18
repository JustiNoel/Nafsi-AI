import { useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../services/api";
import { useAuth } from "../context/AuthContext";
export default function Login() {
  const [form, setForm] = useState({ email: "", password: "", full_name: "" });
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState("");
  const { login } = useAuth();
  const nav = useNavigate();
  const submit = async (e) => {
    e.preventDefault(); setError("");
    try {
      const { data } = await api.post(isRegister ? "/auth/register" : "/auth/login", form);
      login(data.access_token, data.user); nav("/");
    } catch (err) { setError(err.response?.data?.detail || "Something went wrong"); }
  };
  return (
    <div className="min-h-screen flex items-center justify-center bg-nafsi-light">
      <div className="bg-white p-8 rounded-2xl shadow-lg w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-nafsi-teal">🌿 Nafsi AI</h1>
          <p className="text-gray-500 mt-1">Your mental health companion</p>
        </div>
        <form onSubmit={submit} className="space-y-4">
          {isRegister && <input className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green" placeholder="Full name" value={form.full_name} onChange={e => setForm(f => ({...f, full_name: e.target.value}))} required/>}
          <input className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green" type="email" placeholder="Email" value={form.email} onChange={e => setForm(f => ({...f, email: e.target.value}))} required/>
          <input className="w-full border rounded-lg p-3 focus:outline-none focus:ring-2 focus:ring-nafsi-green" type="password" placeholder="Password" value={form.password} onChange={e => setForm(f => ({...f, password: e.target.value}))} required/>
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button className="w-full bg-nafsi-green text-white py-3 rounded-lg font-semibold hover:bg-nafsi-teal transition">{isRegister ? "Create Account" : "Sign In"}</button>
        </form>
        <p className="text-center mt-4 text-sm text-gray-500">
          {isRegister ? "Already have an account?" : "Don't have an account?"}
          <button onClick={() => setIsRegister(!isRegister)} className="text-nafsi-green ml-1 font-medium">{isRegister ? "Sign in" : "Register"}</button>
        </p>
      </div>
    </div>
  );
}
