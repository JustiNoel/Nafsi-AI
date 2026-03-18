import { createContext, useContext, useState, useEffect } from "react";
const AuthContext = createContext(null);
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(() => localStorage.getItem("nafsi_token"));
  useEffect(() => {
    const stored = localStorage.getItem("nafsi_user");
    if (stored) setUser(JSON.parse(stored));
  }, []);
  const login = (tokenStr, userData) => {
    localStorage.setItem("nafsi_token", tokenStr);
    localStorage.setItem("nafsi_user", JSON.stringify(userData));
    setToken(tokenStr); setUser(userData);
  };
  const logout = () => {
    localStorage.removeItem("nafsi_token");
    localStorage.removeItem("nafsi_user");
    setToken(null); setUser(null);
  };
  return (
    <AuthContext.Provider value={{ user, token, login, logout, isAuth: !!token }}>
      {children}
    </AuthContext.Provider>
  );
}
export const useAuth = () => useContext(AuthContext);
